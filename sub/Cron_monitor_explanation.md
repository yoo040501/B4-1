# Cron 설정 설명

이번 과제에서는 `monitor.sh`를 매분 자동 실행하기 위해 `agent-admin` 계정의 crontab에 다음 내용을 등록하였다.

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
```

---

## 1. Cron이란?

`cron`은 Linux/Unix 환경에서 명령어나 스크립트를 지정된 시간에 자동으로 실행해주는 스케줄러이다.

사용자가 직접 실행하지 않아도 정해진 주기에 따라 작업을 반복할 수 있다.

이번 과제에서는 `monitor.sh`를 매분 실행하여 시스템 상태를 자동으로 수집하고 로그로 남기기 위해 사용하였다.

---

## 2. Cron 시간 형식

crontab의 기본 형식은 다음과 같다.

```text
분 시 일 월 요일 명령어
```

예:

```text
* * * * * command
```

각 필드의 의미:

| 위치 | 의미 | 범위 |
|---|---|---|
| 1 | 분 | 0~59 |
| 2 | 시 | 0~23 |
| 3 | 일 | 1~31 |
| 4 | 월 | 1~12 |
| 5 | 요일 | 0~7 |

`*`는 해당 값의 모든 경우를 의미한다.

따라서:

```cron
* * * * *
```

는 모든 분, 모든 시간, 모든 날짜, 모든 월, 모든 요일을 의미하므로 결과적으로 **1분마다 실행**된다.

---

## 3. monitor.sh 실행 부분

```bash
/home/agent-admin/agent-app/bin/monitor.sh
```

cron이 매분 해당 경로의 `monitor.sh`를 실행한다.

스크립트는 다음 작업을 수행한다.

- Agent 프로세스 상태 확인
- TCP 15034 포트 LISTEN 여부 확인
- UFW 방화벽 상태 확인
- CPU 사용률 수집
- 메모리 사용률 수집
- 디스크 사용률 수집
- 임계값 초과 시 WARNING 출력
- `/var/log/agent-app/monitor.log`에 결과 기록

---

## 4. `>/dev/null`

```bash
>/dev/null
```

`>`는 표준 출력(stdout)을 다른 곳으로 보내는 리다이렉션이다.

`/dev/null`은 전달된 데이터를 버리는 특수 파일이다.

따라서:

```bash
command >/dev/null
```

은 명령어의 일반 출력 내용을 화면에 표시하지 않고 버린다는 의미이다.

cron은 백그라운드에서 실행되기 때문에 콘솔 출력이 필요하지 않아 `/dev/null`로 보냈다.

---

## 5. `2>&1`

Linux 프로세스의 기본 입출력 번호는 다음과 같다.

```text
0 : stdin  (표준 입력)
1 : stdout (표준 출력)
2 : stderr (표준 오류)
```

다음 설정:

```bash
2>&1
```

은 표준 오류(stderr, 2번)를 표준 출력(stdout, 1번)과 같은 곳으로 보내라는 의미이다.

앞에서 stdout을 `/dev/null`로 보냈기 때문에 stderr도 동일하게 `/dev/null`로 전달된다.

즉:

```bash
>/dev/null 2>&1
```

은 다음 의미이다.

```text
일반 출력(stdout) ─┐
                  ├─> /dev/null
오류 출력(stderr) ┘
```

따라서 cron에서 실행되는 `monitor.sh`의 화면 출력과 오류 출력은 모두 버려진다.

---

## 6. 출력은 버리는데 로그는 왜 남는가?

`>/dev/null 2>&1`은 `monitor.sh`가 터미널에 출력하는 내용만 버린다.

`monitor.sh` 내부에서는 별도로 다음과 같이 로그 파일에 내용을 기록한다.

```bash
echo "[$TIMESTAMP] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}%"     >> "$LOG_FILE"
```

여기서 `>>`는 기존 파일 내용을 지우지 않고 파일 끝에 새로운 내용을 추가한다.

따라서 cron 실행 화면은 보이지 않지만:

```text
/var/log/agent-app/monitor.log
```

에는 모니터링 결과가 계속 누적된다.

---

## 7. 실제 동작 확인

crontab 등록 내용 확인:

```bash
sudo -u agent-admin crontab -l
```

등록된 내용:

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
```

로그 확인:

```bash
sudo tail -n 5 /var/log/agent-app/monitor.log
```

예:

```text
[2026-09-08 15:04:01] PID:3071 CPU:4.8% MEM:4.8% DISK_USED:1%
[2026-09-08 15:05:01] PID:3071 CPU:4.9% MEM:4.0% DISK_USED:1%
[2026-09-08 15:06:02] PID:3071 CPU:3.3% MEM:5.0% DISK_USED:1%
```

약 1분 간격으로 새로운 로그가 생성되는 것을 통해 cron이 정상적으로 실행되고 있음을 확인할 수 있다.

---

## 8. 전체 동작 흐름

```text
cron
  ↓
매분 monitor.sh 실행
  ↓
프로세스 / 포트 / 방화벽 / 리소스 확인
  ↓
터미널 출력은 /dev/null로 버림
  ↓
monitor.log에는 상태 정보 기록
  ↓
다음 분에 다시 실행
```

---

## 9. 이번 과제에서 Cron을 사용한 이유

모니터링 스크립트를 사람이 직접 실행하면 주기적인 상태 수집이 어렵고 실행을 빠뜨릴 수 있다.

따라서 cron을 사용해 `monitor.sh`를 매분 자동 실행하도록 구성하였다.

이를 통해 시스템 상태가 일정한 주기로 `monitor.log`에 누적되며, 장애 발생 시 과거의 CPU, 메모리, 디스크 및 프로세스 상태를 확인할 수 있도록 하였다.
