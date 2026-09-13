#!/bin/bash

# 모니터링 대상 애플리케이션 이름과 포트
APP_NAME="agent-app-linux-x86"
PORT=15034

# 로그 저장 위치
LOG_DIR="/var/log/agent-app"
LOG_FILE="$LOG_DIR/monitor.log"

# 자원 사용률 경고 기준
CPU_THRESHOLD=20
MEM_THRESHOLD=10
DISK_THRESHOLD=80

echo "====== SYSTEM MONITOR RESULT ======"
echo
echo "[HEALTH CHECK]"

# pgrep -f : 전체 실행 명령줄에서 APP_NAME을 검색
# head -n 1 : 검색된 PID 중 첫 번째 PID만 사용
PID=$(pgrep -f "$APP_NAME" | head -n 1)

# -z : PID 문자열이 비어 있는지 검사
# 프로세스가 없으면 Health Check 실패로 판단하고 exit 1
if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    exit 1
else
    echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
fi

# ss -ltn
# -l : LISTEN 상태
# -t : TCP
# -n : 포트를 숫자로 표시
# grep -q : PORT가 존재하는지만 확인하고 결과는 출력하지 않음
if ss -ltn | grep -q ":${PORT} "; then
    echo "Checking port $PORT... [OK]"
else
    echo "Checking port $PORT... [FAIL]"
    exit 1
fi

echo
echo "[FIREWALL CHECK]"

# sudo -n : 비밀번호 입력 없이 sudo 실행
# 2>/dev/null : 오류 메시지는 화면에 출력하지 않음
FIREWALL_STATUS=$(sudo -n /usr/sbin/ufw status 2>/dev/null)

# UFW 출력에 'Status: active'가 존재하는지 확인
if echo "$FIREWALL_STATUS" | grep -q "^Status: active"; then
    echo "Checking firewall... [OK]"
else
    echo "[WARNING] UFW is inactive or status cannot be checked"
fi

# top을 한 번 실행하여 CPU idle 값을 가져옴
# 실제 CPU 사용률 = 100 - idle
CPU_IDLE=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}')
CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN {printf "%.1f", 100-idle}')

# free 명령의 Mem 행에서
# 사용 메모리($3) / 전체 메모리($2) * 100 계산
MEM_USAGE=$(free | awk '/Mem:/ {
    printf "%.1f", ($3/$2)*100
}')

# df / : Root Partition 디스크 사용량 확인
# NR==2 : 실제 데이터가 있는 두 번째 줄 선택
# gsub : '%' 문자 제거
DISK_USAGE=$(df / | awk 'NR==2 {
    gsub("%", "", $5)
    print $5
}')

echo
echo "[RESOURCE MONITORING]"
echo "CPU Usage : ${CPU_USAGE}%"
echo "MEM Usage : ${MEM_USAGE}%"
echo "DISK Used : ${DISK_USAGE}%"

# CPU 사용률은 실수일 수 있으므로 awk로 임계값 비교
if awk "BEGIN {exit !($CPU_USAGE > $CPU_THRESHOLD)}"; then
    echo "[WARNING] CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)"
fi

# 메모리 사용률도 실수이므로 awk로 비교
if awk "BEGIN {exit !($MEM_USAGE > $MEM_THRESHOLD)}"; then
    echo "[WARNING] MEM threshold exceeded (${MEM_USAGE}% > ${MEM_THRESHOLD}%)"
fi

# 디스크 사용률은 정수이므로 Bash의 -gt(Greater Than) 사용
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING] DISK threshold exceeded (${DISK_USAGE}% > ${DISK_THRESHOLD}%)"
fi

# 현재 날짜/시간 생성
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# >> 를 사용하여 기존 로그를 지우지 않고 파일 끝에 새 로그를 추가
echo "[$TIMESTAMP] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}%" \
    >> "$LOG_FILE"

echo
echo "[INFO] Log appended: $LOG_FILE"
