#!/bin/bash

APP_NAME="agent-app-linux-x86"
PORT=15034

LOG_DIR="/var/log/agent-app"
LOG_FILE="$LOG_DIR/monitor.log"

CPU_THRESHOLD=20
MEM_THRESHOLD=10
DISK_THRESHOLD=80

echo "====== SYSTEM MONITOR RESULT ======"
echo
echo "[HEALTH CHECK]"

PID=$(pgrep -f "$APP_NAME" | head -n 1)

if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    exit 1
else
    echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
fi

if ss -ltn | grep -q ":${PORT} "; then
    echo "Checking port $PORT... [OK]"
else
    echo "Checking port $PORT... [FAIL]"
    exit 1
fi

echo
echo "[FIREWALL CHECK]"

FIREWALL_STATUS=$(sudo -n /usr/sbin/ufw status 2>/dev/null)

if echo "$FIREWALL_STATUS" | grep -q "^Status: active"; then
    echo "Checking firewall... [OK]"
else
    echo "[WARNING] UFW is inactive or status cannot be checked"
fi

CPU_IDLE=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}')
CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN {printf "%.1f", 100-idle}')

MEM_USAGE=$(free | awk '/Mem:/ {
    printf "%.1f", ($3/$2)*100
}')

DISK_USAGE=$(df / | awk 'NR==2 {
    gsub("%", "", $5)
    print $5
}')

echo
echo "[RESOURCE MONITORING]"
echo "CPU Usage : ${CPU_USAGE}%"
echo "MEM Usage : ${MEM_USAGE}%"
echo "DISK Used : ${DISK_USAGE}%"

if awk "BEGIN {exit !($CPU_USAGE > $CPU_THRESHOLD)}"; then
    echo "[WARNING] CPU threshold exceeded (${CPU_USAGE}% > ${CPU_THRESHOLD}%)"
fi

if awk "BEGIN {exit !($MEM_USAGE > $MEM_THRESHOLD)}"; then
    echo "[WARNING] MEM threshold exceeded (${MEM_USAGE}% > ${MEM_THRESHOLD}%)"
fi

if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "[WARNING] DISK threshold exceeded (${DISK_USAGE}% > ${DISK_THRESHOLD}%)"
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}%" \
    >> "$LOG_FILE"

echo
echo "[INFO] Log appended: $LOG_FILE"
