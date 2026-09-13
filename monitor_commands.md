# monitor.sh 명령어 설명

이 문서는 `monitor.sh`에서 사용한 주요 Bash/Linux 명령어와 각 명령어의 역할을 정리한 문서이다.

---

## 1. 프로세스 확인

```bash
PID=$(pgrep -f "$APP_NAME" | head -n 1)
```

- `pgrep` : 실행 중인 프로세스에서 조건에 맞는 PID를 찾는다.
- `-f` : 프로세스 이름뿐 아니라 전체 실행 명령줄을 기준으로 검색한다.
- `head -n 1` : 검색 결과 중 첫 번째 PID 하나만 가져온다.
- `$()` : 명령어 실행 결과를 변수에 저장하는 Command Substitution이다.

예:

```bash
pgrep -af "agent-app-linux-x86"
```

실행 중인 프로세스의 PID와 전체 실행 명령을 확인할 수 있다.

---

## 2. 프로세스 존재 여부 확인

```bash
if [ -z "$PID" ]; then
```

- `[ ... ]` : Bash에서 조건을 검사한다.
- `-z` : 문자열 길이가 0인지 확인한다.
- PID가 비어 있으면 프로세스를 찾지 못한 것으로 판단한다.

```bash
exit 1
```

- 스크립트를 비정상 상태로 종료한다.
- 일반적으로 `exit 0`은 정상 종료, `exit 1`은 오류 또는 실패를 의미한다.

---

## 3. TCP 포트 확인

```bash
ss -ltn
```

`ss`는 네트워크 소켓 상태를 확인하는 명령어이다.

옵션:

- `-l` : LISTEN 상태의 소켓만 표시
- `-t` : TCP 소켓 표시
- `-n` : 서비스명 대신 포트 번호를 숫자로 표시

따라서 `ss -ltn`은 현재 LISTEN 중인 TCP 포트를 숫자로 확인하는 명령이다.

---

## 4. grep을 이용한 포트 검색

```bash
ss -ltn | grep -q ":${PORT} "
```

- `|` : 앞 명령어의 출력을 뒤 명령어의 입력으로 전달하는 Pipe이다.
- `grep` : 문자열을 검색한다.
- `-q` : 검색 결과를 출력하지 않고 성공/실패 여부만 반환한다.

`PORT=15034`라면 실제로는 15034 포트가 LISTEN 상태인지 검사한다.

---

## 5. UFW 방화벽 상태 확인

```bash
FIREWALL_STATUS=$(sudo -n /usr/sbin/ufw status 2>/dev/null)
```

- `ufw status` : UFW 방화벽 상태를 확인한다.
- `sudo -n` : 비밀번호를 요청하지 않고 sudo 명령을 실행한다.
- cron에서는 사용자가 비밀번호를 입력할 수 없기 때문에 `-n` 옵션을 사용하였다.
- `2>/dev/null` : 표준 오류(stderr)를 `/dev/null`로 보내 화면에 출력하지 않는다.

Linux의 기본 입출력 번호:

```text
0 : stdin  (표준 입력)
1 : stdout (표준 출력)
2 : stderr (표준 오류)
```

`/dev/null`은 전달된 데이터를 버리는 특수 파일이다.

---

## 6. UFW 활성 상태 검사

```bash
echo "$FIREWALL_STATUS" | grep -q "^Status: active"
```

- `echo` : 변수 값을 출력한다.
- `grep -q` : 해당 문자열이 존재하는지만 검사한다.
- `^` : 문자열의 시작을 의미하는 정규표현식이다.

따라서 `Status: active`로 시작하는 줄이 있는지 검사한다.

---

## 7. CPU 사용률 수집

```bash
CPU_IDLE=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}')
```

### `top`

CPU, 메모리, 프로세스 상태 등을 확인하는 명령어이다.

옵션:

- `-b` : Batch Mode로 출력
- `-n1` : 한 번만 출력

스크립트에서는 지속적으로 갱신되는 화면이 필요하지 않기 때문에 한 번의 값만 가져온다.

### `awk`

```bash
awk '/Cpu\(s\)/ {print $8}'
```

`awk`는 텍스트를 열 단위로 처리할 때 사용하는 명령어이다.

- `/Cpu\(s\)/` : `Cpu(s)`가 포함된 줄을 찾는다.
- `print $8` : 해당 줄의 8번째 필드를 출력한다.

여기에서는 CPU idle 값을 가져오기 위해 사용하였다.

---

## 8. CPU 사용률 계산

```bash
CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN {printf "%.1f", 100-idle}')
```

CPU idle이 93.5%라면:

```text
100 - 93.5 = 6.5%
```

따라서 CPU 사용률은 6.5%가 된다.

- `awk -v` : Bash 변수 값을 awk 내부 변수로 전달한다.
- `printf "%.1f"` : 소수점 첫째 자리까지 출력한다.

---

## 9. 메모리 사용률 수집

```bash
MEM_USAGE=$(free | awk '/Mem:/ {
    printf "%.1f", ($3/$2)*100
}')
```

`free`는 시스템의 메모리 상태를 확인한다.

`Mem:` 행에서:

- `$2` : 전체 메모리
- `$3` : 사용 중인 메모리

따라서 다음 계산으로 메모리 사용률을 구한다.

```text
사용 중인 메모리 / 전체 메모리 × 100
```

---

## 10. 디스크 사용률 수집

```bash
DISK_USAGE=$(df / | awk 'NR==2 {
    gsub("%", "", $5)
    print $5
}')
```

### `df /`

`df`는 파일 시스템의 디스크 사용량을 확인한다.

`/`를 지정했기 때문에 Root Partition의 사용률을 확인한다.

### `NR==2`

`awk`에서 `NR`은 현재 처리 중인 줄 번호를 의미한다.

첫 번째 줄은 제목이므로 실제 데이터가 있는 두 번째 줄만 처리한다.

### `gsub`

```bash
gsub("%", "", $5)
```

`gsub`는 문자열을 치환한다.

예:

```text
23% → 23
```

숫자 비교를 위해 `%` 문자를 제거한다.

---

## 11. CPU / 메모리 임계값 비교

```bash
if awk "BEGIN {exit !($CPU_USAGE > $CPU_THRESHOLD)}"; then
```

CPU와 메모리 사용률은 `25.3`과 같이 실수일 수 있다.

Bash의 기본 숫자 비교보다 `awk`가 실수 비교에 적합하기 때문에 `awk`를 이용하여 임계값을 비교하였다.

예:

```text
CPU_USAGE = 25.3
CPU_THRESHOLD = 20

25.3 > 20 → WARNING 출력
```

---

## 12. 디스크 임계값 비교

```bash
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
```

`-gt`는 Greater Than, 즉 왼쪽 값이 오른쪽 값보다 큰지 비교한다.

주요 Bash 정수 비교 연산자:

```text
-eq : 같다
-ne : 다르다
-gt : 크다
-ge : 크거나 같다
-lt : 작다
-le : 작거나 같다
```

디스크 사용률은 `%`를 제거한 정수이기 때문에 Bash의 `-gt`를 사용하였다.

---

## 13. 현재 날짜와 시간 생성

```bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
```

`date` 명령어를 이용해 현재 날짜와 시간을 가져온다.

포맷:

```text
%Y : 년
%m : 월
%d : 일
%H : 시
%M : 분
%S : 초
```

결과 예:

```text
2026-09-08 15:05:01
```

---

## 14. 로그 누적 기록

```bash
echo "[$TIMESTAMP] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}%" \
    >> "$LOG_FILE"
```

`echo`로 로그 문자열을 생성하고 `>>`를 이용하여 파일 끝에 추가한다.

리다이렉션 차이:

```text
>  : 기존 내용을 지우고 새로 작성
>> : 기존 내용 뒤에 추가
```

모니터링 로그는 이전 기록을 유지해야 하기 때문에 `>>`를 사용하였다.

---

## 15. monitor.sh 전체 동작 흐름

```text
pgrep
  ↓
Agent 프로세스 존재 여부 확인
  ↓
실패 시 exit 1

ss
  ↓
TCP 15034 LISTEN 여부 확인
  ↓
실패 시 exit 1

ufw status
  ↓
방화벽 활성 상태 확인
  ↓
비활성 또는 확인 실패 시 WARNING

top
  ↓
CPU 사용률 수집

free
  ↓
메모리 사용률 수집

df
  ↓
Root Partition 디스크 사용률 수집

awk / Bash 조건문
  ↓
설정한 임계값과 비교
  ↓
초과 시 WARNING

date
  ↓
현재 시간 생성

echo >>
  ↓
monitor.log에 상태 누적 기록
```

## 요약

`monitor.sh`는 `pgrep`과 `ss`를 이용해 애플리케이션의 프로세스와 포트 상태를 Health Check하고, `top`, `free`, `df`를 이용해 CPU, 메모리, 디스크 사용률을 수집한다.

수집한 값은 `awk`와 Bash 조건문을 이용해 임계값과 비교하며, 초과 시 `[WARNING]`을 출력한다. 마지막으로 `date`를 통해 현재 시간을 추가하고 `>>` 리다이렉션으로 `/var/log/agent-app/monitor.log`에 시스템 상태를 누적 기록한다.
