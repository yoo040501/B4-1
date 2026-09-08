# 1. 수행 환경

* OS: Ubuntu 25.10
* 아키텍처: x86_64
* 실행 환경: OrbStack Linux Machine  [OrbStack Linux Machine과 VM 차이](./Diff_LinuxMachine-VM.md)
* 제공 애플리케이션: `agent-app-linux-x86`

---

# 2. SSH 보안 설정

SSH 기본 포트를 22번에서 20022번으로 변경하고 Root 원격 로그인을 차단하였다.

설정 확인:

```bash
sudo sshd -T | grep -E '^(port|permitrootlogin)'
```

확인 결과:

```text
port 20022
permitrootlogin no
```

SSH 포트 리슨 상태 확인:

```bash
sudo ss -tulnp | grep 20022
```

확인 결과:

```text
tcp LISTEN 0 4096 0.0.0.0:20022 0.0.0.0:* users:(("systemd",pid=1,...))
tcp LISTEN 0 4096 [::]:20022    [::]:*    users:(("systemd",pid=1,...))
```

따라서 SSH 서비스가 TCP 20022 포트에서 정상적으로 LISTEN 중이며 Root 원격 로그인도 차단되어 있음을 확인하였다.

---

# 3. 방화벽 설정

Ubuntu의 UFW를 사용하여 인바운드 접근을 제한하였다.

허용 포트:

* TCP 20022: SSH
* TCP 15034: Agent Application

확인 명령:

```bash
sudo ufw status
```

확인 결과:

```text
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere
15034/tcp                  ALLOW       Anywhere
20022/tcp (v6)             ALLOW       Anywhere (v6)
15034/tcp (v6)             ALLOW       Anywhere (v6)
```

UFW가 활성화되어 있으며 요구된 두 포트만 인바운드 접근을 허용하도록 구성하였다.

---

# 4. 계정 및 그룹 구성

역할에 따라 다음 계정을 생성하였다.

```text
agent-admin : 운영 및 관리
agent-dev   : 개발 및 모니터링 스크립트 작성
agent-test  : QA 및 테스트
```

그룹은 다음과 같이 구성하였다.

```text
agent-common
 ├─ agent-admin
 ├─ agent-dev
 └─ agent-test

agent-core
 ├─ agent-admin
 └─ agent-dev
```

확인 명령:

```bash
id agent-admin
id agent-dev
id agent-test
```

결과:

```text
uid=1000(agent-admin) gid=1002(agent-admin)
groups=1002(agent-admin),1000(agent-common),1001(agent-core)

uid=1001(agent-dev) gid=1003(agent-dev)
groups=1003(agent-dev),1000(agent-common),1001(agent-core)

uid=1002(agent-test) gid=1004(agent-test)
groups=1004(agent-test),1000(agent-common)
```

따라서 `agent-test`는 보안 영역인 `agent-core`에 포함하지 않고, `agent-admin`과 `agent-dev`만 포함하도록 최소 권한 원칙을 적용하였다.

---

# 5. 디렉토리 및 권한 설정

디렉토리 구조:

```text
/home/agent-admin/agent-app
├── upload_files
├── api_keys
└── bin

/var/log/agent-app
```

권한 확인:

```bash
sudo ls -ld /home/agent-admin/agent-app/upload_files
sudo ls -ld /home/agent-admin/agent-app/api_keys
sudo ls -ld /var/log/agent-app
```

결과:

```text
drwxrws---+ agent-admin agent-common ... upload_files
drwxrws---+ agent-admin agent-core   ... api_keys
drwxrws---+ agent-admin agent-core   ... /var/log/agent-app
```

`upload_files`는 `agent-common` 그룹에 속한 세 계정이 사용할 수 있도록 설정하였다.

`api_keys`와 `/var/log/agent-app`은 `agent-core` 그룹의 `agent-admin`, `agent-dev`만 접근할 수 있도록 제한하였다.

SetGID도 적용하여 디렉토리 내부에 새 파일 생성 시 해당 디렉토리의 그룹을 자동으로 상속하도록 구성하였다.

---

# 6. ACL 설정

공유 및 보안 디렉토리에 ACL을 적용하였다.

## upload_files

```text
owner : agent-admin
group : agent-common

user::rwx
group::rwx
group:agent-common:rwx
mask::rwx
other::---
```

Default ACL:

```text
default:user::rwx
default:group::rwx
default:group:agent-common:rwx
default:mask::rwx
default:other::---
```

## api_keys

```text
owner : agent-admin
group : agent-core

user::rwx
group::rwx
group:agent-core:rwx
mask::rwx
other::---
```

## /var/log/agent-app

```text
owner : agent-admin
group : agent-core

user::rwx
group::rwx
group:agent-core:rwx
mask::rwx
other::---
```

접근 테스트 결과:

```text
agent-test → upload_files 쓰기 가능
agent-test → api_keys 접근 불가
agent-dev  → api_keys 쓰기 가능
```

따라서 공유 디렉토리와 보안 디렉토리의 접근 권한이 요구사항대로 분리되었음을 확인하였다.

---

# 7. 애플리케이션 실행 환경

환경 변수는 다음과 같이 설정하였다.

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
```

키 파일:

```text
/home/agent-admin/agent-app/api_keys/secret.key
```

키 내용:

```text
agent_api_key_test
```

제공 문서에서는 `AGENT_KEY_PATH`를 키 파일 전체 경로로 지정하고 `t_secret.key`를 사용하도록 안내되어 있었으나, 실제 제공 바이너리의 Boot Sequence에서는 `AGENT_KEY_PATH`에 `api_keys` 디렉토리 경로를 요구하고 파일명은 `secret.key`를 요구하였다.

따라서 제공 애플리케이션의 실제 검증 기준에 맞추어 설정하였다.

---

# 8. Agent Application 실행

`agent-admin` 일반 계정으로 다음 애플리케이션을 실행하였다.

```bash
./agent-app-linux-x86
```

실행 결과:

```text
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]

All Boot Checks Passed!
Agent READY
```

따라서 Boot Sequence 5단계가 모두 정상적으로 통과하였다.

애플리케이션 포트 확인:

```bash
sudo ss -ltnp | grep 15034
```

결과:

```text
LISTEN 0 1 0.0.0.0:15034 0.0.0.0:* users:(("agent-app-linux",pid=3072,...))
```

따라서 애플리케이션이 `0.0.0.0:15034`에서 정상적으로 LISTEN 중임을 확인하였다.

---

# 9. monitor.sh 구현

스크립트 위치:

```text
/home/agent-admin/agent-app/bin/monitor.sh
```

소유자 및 그룹:

```text
owner : agent-dev
group : agent-core
```

권한:

```text
750
rwxr-x---
```

스크립트에서는 다음 기능을 구현하였다.

* Agent 프로세스 상태 확인
* TCP 15034 LISTEN 상태 확인
* UFW 활성 상태 확인
* CPU 사용률 수집
* 메모리 사용률 수집
* Root Partition 디스크 사용률 수집
* CPU 20% 초과 시 WARNING
* MEM 10% 초과 시 WARNING
* DISK 80% 초과 시 WARNING
* `/var/log/agent-app/monitor.log` 기록

실행 명령:

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

실행 결과:

```text
====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]

Checking process 'agent-app-linux-x86'... [OK] (PID: 3071)

Checking port 15034... [OK]

[FIREWALL CHECK]

Checking firewall... [OK]

[RESOURCE MONITORING]

CPU Usage : 6.5%
MEM Usage : 4.8%
DISK Used : 1%

[INFO] Log appended: /var/log/agent-app/monitor.log
```

애플리케이션의 CPU 부하가 증가한 시점에는 다음과 같이 임계값 경고가 정상 발생하였다.

```text
CPU Usage : 100.0%

[WARNING] CPU threshold exceeded (100.0% > 20%)
```

---

# 10. 모니터링 로그 기록

로그 파일:

```text
/var/log/agent-app/monitor.log
```

로그 포맷:

```text
[YYYY-MM-DD HH:MM:SS] PID:... CPU:...% MEM:...% DISK_USED:...%
```

확인 결과:

```text
[2026-09-08 15:04:01] PID:3071 CPU:4.8% MEM:4.8% DISK_USED:1%
[2026-09-08 15:05:01] PID:3071 CPU:4.9% MEM:4.0% DISK_USED:1%
[2026-09-08 15:06:02] PID:3071 CPU:3.3% MEM:5.0% DISK_USED:1%
[2026-09-08 15:06:23] PID:3071 CPU:6.5% MEM:4.8% DISK_USED:1%
```

프로세스 ID와 CPU, 메모리, 디스크 사용률이 요구된 형태로 정상 기록됨을 확인하였다.

---

# 11. Logrotate 설정

`monitor.log`가 과도하게 증가하여 디스크 공간을 차지하는 것을 방지하기 위해 logrotate를 사용하였다.

설정 파일:

```text
/etc/logrotate.d/agent-app
```

설정:

```text
/var/log/agent-app/monitor.log {
    su agent-admin agent-core
    size 10M
    rotate 10
    compress
    missingok
    notifempty
    copytruncate
}
```

정책:

```text
최대 크기 : 10MB
보관 개수 : 10개
과거 로그 : gzip 압축
```

강제 회전 테스트:

```bash
sudo logrotate -f /etc/logrotate.d/agent-app
```

결과:

```text
monitor.log
monitor.log.1.gz
```

압축 로그 확인:

```bash
sudo zcat /var/log/agent-app/monitor.log.1.gz
```

결과:

```text
[2026-09-08 14:56:17] PID:3071 CPU:4.9% MEM:4.4% DISK_USED:1%
[2026-09-08 14:58:47] PID:3071 CPU:6.3% MEM:4.3% DISK_USED:1%
[2026-09-08 14:59:40] PID:3071 CPU:100.0% MEM:4.5% DISK_USED:1%
[2026-09-08 15:03:01] PID:3071 CPU:4.9% MEM:4.5% DISK_USED:1%
```

로그 회전과 압축 및 기존 로그 보존이 정상 동작함을 확인하였다.

---

# 12. Cron 자동 실행

`monitor.sh`는 `agent-admin` 계정의 crontab에 등록하였다.

확인 명령:

```bash
sudo -u agent-admin crontab -l
```

등록 내용:

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
```

매분 실행되도록 구성하였다.

자동 실행 확인 결과:

```text
[2026-09-08 15:04:01] PID:3071 CPU:4.8% MEM:4.8% DISK_USED:1%
[2026-09-08 15:05:01] PID:3071 CPU:4.9% MEM:4.0% DISK_USED:1%
[2026-09-08 15:06:02] PID:3071 CPU:3.3% MEM:5.0% DISK_USED:1%
```

약 1분 간격으로 `monitor.log`에 새로운 데이터가 자동으로 누적되는 것을 확인하였다.

또한 logrotate 이후 새로운 `monitor.log`가 생성된 후에도 cron에 의해 다시 로그가 정상 기록되었다.

---

# 13. 최종 결과

이번 미션을 통해 다음 서버 운영 환경을 구성하였다.

* SSH 포트를 20022로 변경
* Root SSH 원격 로그인 차단
* UFW 활성화 및 필요 포트만 허용
* 역할 기반 계정 및 그룹 구성
* ACL을 이용한 공유/보안 디렉토리 분리
* 환경 변수를 이용한 Agent 실행 환경 구성
* 일반 계정으로 Agent Application 실행
* TCP 15034 서비스 운영
* Bash 기반 `monitor.sh` 구현
* 프로세스/포트/CPU/MEM/DISK 상태 관제
* 자원 임계값 초과 WARNING 출력
* 운영 로그 자동 기록
* crontab을 이용한 매분 자동 실행
* logrotate를 통한 10MB/10개 로그 보존 정책 적용

이를 통해 서버의 접근 보안부터 계정 권한 관리, 애플리케이션 실행 환경, 상태 관제 및 로그 자동화까지 기본적인 Linux 서버 운영 흐름을 구현하였다.

