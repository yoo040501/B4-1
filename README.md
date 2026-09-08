# Linux 서버 운영 및 모니터링

## 1. 수행 환경

* OS: Ubuntu 25.10
* 아키텍처: x86_64
* 실행 환경: OrbStack Linux Machine
* 제공 애플리케이션: `agent-app-linux-x86`

OrbStack Linux Machine과 Docker/VM의 차이는 아래 문서에 별도로 정리하였다.

[OrbStack Linux Machine과 VM 차이](./Diff_LinuxMachine-VM.md)

---

# 2. SSH 보안 설정

SSH 기본 포트를 22번에서 `20022`번으로 변경하고 Root 원격 로그인을 차단하였다.

OrbStack의 Ubuntu 환경에서는 SSH가 `ssh.service`가 아닌 `ssh.socket`을 통해 22번 포트를 LISTEN하고 있었기 때문에 socket 설정도 함께 변경하였다.

## SSH Socket 포트 변경

```bash
sudo systemctl edit ssh.socket
```

다음 내용을 추가하였다.

```ini
[Socket]
ListenStream=
ListenStream=20022
```

기존 `ListenStream` 값을 초기화한 뒤 20022 포트를 사용하도록 설정하였다.

## SSH 설정 파일 수정

```bash
sudo vim /etc/ssh/sshd_config
```

설정:

```text
Port 20022
PermitRootLogin no
```

설정 적용:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket
```

설정 확인:

```bash
sudo sshd -T | grep -E '^(port|permitrootlogin)'
```

결과:

```text
port 20022
permitrootlogin no
```

SSH 포트 LISTEN 상태 확인:

```bash
sudo ss -tulnp | grep 20022
```

결과:

```text
tcp LISTEN 0 4096 0.0.0.0:20022 0.0.0.0:* users:(("systemd",pid=1,...))
tcp LISTEN 0 4096 [::]:20022    [::]:*    users:(("systemd",pid=1,...))
```

이를 통해 SSH 서비스가 TCP 20022 포트에서 정상적으로 LISTEN 중이며 Root 원격 로그인이 차단되어 있음을 확인하였다.

---

# 3. 방화벽 설정

Ubuntu의 UFW를 사용하여 외부에서 접근할 수 있는 인바운드 포트를 제한하였다.

허용 포트:

* TCP 20022: SSH
* TCP 15034: Agent Application

## UFW 설정

```bash
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

설정 확인:

```bash
sudo ufw status
```

결과:

```text
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere
15034/tcp                  ALLOW       Anywhere
20022/tcp (v6)             ALLOW       Anywhere (v6)
15034/tcp (v6)             ALLOW       Anywhere (v6)
```

UFW가 활성화되어 있으며 필요한 두 포트만 인바운드 접근을 허용하도록 구성하였다.

---

# 4. 계정 및 그룹 구성

역할에 따라 다음 계정을 생성하였다.

```text
agent-admin : 운영 및 관리, cron 실행
agent-dev   : 개발 및 monitor.sh 작성
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

## 그룹 생성

```bash
sudo groupadd agent-common
sudo groupadd agent-core
```

## 계정 생성

```bash
sudo useradd -m -s /bin/bash agent-admin
sudo useradd -m -s /bin/bash agent-dev
sudo useradd -m -s /bin/bash agent-test
```

## 그룹 배정

```bash
sudo usermod -aG agent-common,agent-core agent-admin
sudo usermod -aG agent-common,agent-core agent-dev
sudo usermod -aG agent-common agent-test
```

확인:

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

`agent-test`는 보안 영역인 `agent-core`에 포함하지 않고, `agent-admin`과 `agent-dev`만 포함하여 최소 권한 원칙을 적용하였다.

---

# 5. 디렉토리 및 권한 설정

디렉토리 구조는 다음과 같이 구성하였다.

```text
/home/agent-admin/agent-app
├── upload_files
├── api_keys
└── bin

/var/log/agent-app
```

## 디렉토리 생성

```bash
sudo mkdir -p /home/agent-admin/agent-app/upload_files
sudo mkdir -p /home/agent-admin/agent-app/api_keys
sudo mkdir -p /home/agent-admin/agent-app/bin
sudo mkdir -p /var/log/agent-app
```

## upload_files

`agent-common` 그룹의 모든 사용자가 읽기/쓰기를 수행할 수 있도록 설정하였다.

```bash
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
```

## api_keys

`agent-core` 그룹만 접근할 수 있도록 설정하였다.

```bash
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys
```

## 로그 디렉토리

```bash
sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
```

## bin 디렉토리

```bash
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2770 /home/agent-admin/agent-app/bin
```

## 상위 디렉토리

하위 디렉토리로 이동하기 위해 필요한 최소 실행 권한을 설정하였다.

```bash
sudo chown agent-admin:agent-common /home/agent-admin/agent-app
sudo chmod 2710 /home/agent-admin/agent-app
sudo chmod 711 /home/agent-admin
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

`2770`의 앞자리 `2`는 SetGID를 의미한다.

이를 통해 해당 디렉토리 내부에서 새 파일을 생성할 경우 부모 디렉토리의 그룹을 상속하도록 설정하였다.

---

# 6. ACL 설정

기본 Unix 권한과 함께 ACL을 적용하여 새로 생성되는 파일에도 그룹 권한이 유지되도록 구성하였다.

## ACL 설치 확인

```bash
sudo apt install -y acl
```

## upload_files

```bash
sudo setfacl -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
```

## api_keys

```bash
sudo setfacl -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
```

## 로그 디렉토리

```bash
sudo setfacl -m g:agent-core:rwx /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app
```

ACL 확인:

```bash
sudo getfacl /home/agent-admin/agent-app/upload_files
sudo getfacl /home/agent-admin/agent-app/api_keys
sudo getfacl /var/log/agent-app
```

`upload_files`의 주요 설정:

```text
user::rwx
group::rwx
group:agent-common:rwx
mask::rwx
other::---

default:user::rwx
default:group::rwx
default:group:agent-common:rwx
default:mask::rwx
default:other::---
```

`api_keys`와 `/var/log/agent-app`은 `agent-core` 그룹에 동일한 방식으로 ACL을 적용하였다.

## 실제 접근 권한 테스트

`agent-test`가 `upload_files`에 파일을 생성할 수 있는지 확인하였다.

```bash
sudo -u agent-test touch /home/agent-admin/agent-app/upload_files/test.txt
```

성공하였다.

반면 `agent-test`가 `api_keys`에 접근하려고 하면:

```bash
sudo -u agent-test touch /home/agent-admin/agent-app/api_keys/test.txt
```

다음과 같이 접근이 거부되었다.

```text
Permission denied
```

`agent-dev`는 `agent-core` 구성원이므로 접근이 가능하였다.

```bash
sudo -u agent-dev touch /home/agent-admin/agent-app/api_keys/dev-test.txt
```

테스트 파일 삭제:

```bash
sudo rm -f /home/agent-admin/agent-app/upload_files/test.txt
sudo rm -f /home/agent-admin/agent-app/api_keys/dev-test.txt
```

이를 통해 공유 디렉토리와 보안 디렉토리의 권한이 의도대로 분리되었음을 확인하였다.

---

# 7. 애플리케이션 실행 환경

제공 애플리케이션을 실행하기 위한 환경 변수를 설정하였다.

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
```

환경 변수 확인:

```bash
env | grep '^AGENT_'
```

환경 변수가 로그인 시에도 유지되도록 `agent-admin` 계정의 `~/.bashrc`에 동일한 내용을 등록하였다.

## 키 파일 생성

실제 제공 바이너리가 요구하는 키 파일은 다음 경로에 생성하였다.

```text
/home/agent-admin/agent-app/api_keys/secret.key
```

생성:

```bash
echo 'agent_api_key_test' | sudo tee \
/home/agent-admin/agent-app/api_keys/secret.key
```

소유권 및 권한:

```bash
sudo chown agent-admin:agent-core \
/home/agent-admin/agent-app/api_keys/secret.key

sudo chmod 660 \
/home/agent-admin/agent-app/api_keys/secret.key
```

키 내용:

```text
agent_api_key_test
```

## 문서와 제공 바이너리 차이

과제 문서에는 다음과 같이 안내되어 있었다.

```text
AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
```

그러나 실제 제공 바이너리를 실행한 결과:

```text
Expected: /home/agent-admin/agent-app/api_keys
Missing File: secret.key
```

를 요구하였다.

따라서 실제 실행 검증 결과에 맞추어 다음과 같이 설정하였다.

```text
AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys
키 파일명=secret.key
```

---

# 8. Agent Application 실행

현재 환경이 `x86_64`이므로 제공된 `agent-app-linux-x86` 바이너리를 사용하였다.

실행 권한 및 소유권:

```bash
sudo chown agent-admin:agent-core \
/home/agent-admin/agent-app/agent-app-linux-x86

sudo chmod 750 \
/home/agent-admin/agent-app/agent-app-linux-x86
```

`agent-admin` 계정으로 실행하였다.

```bash
sudo -iu agent-admin
cd "$AGENT_HOME"
./agent-app-linux-x86
```

Boot Sequence 결과:

```text
[1/5] Checking User Account               [OK]
[2/5] Verifying Environment Variables     [OK]
[3/5] Checking Required Files             [OK]
[4/5] Checking Port Availability          [OK]
[5/5] Verifying Log Permission            [OK]

All Boot Checks Passed!
Agent READY
```

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

요구사항에 따라 `agent-dev`가 작성하고 `agent-core` 그룹이 실행할 수 있도록 구성하였다.

```bash
sudo chown agent-dev:agent-core \
/home/agent-admin/agent-app/bin/monitor.sh

sudo chmod 750 \
/home/agent-admin/agent-app/bin/monitor.sh
```

권한:

```text
-rwxr-x--- agent-dev agent-core monitor.sh
```

스크립트에서는 다음 기능을 구현하였다.

* Agent 프로세스 상태 확인
* TCP 15034 LISTEN 상태 확인
* 비정상 상태일 경우 `exit 1`
* UFW 활성 상태 확인
* UFW 비활성 시 WARNING 출력
* CPU 사용률 수집
* 메모리 사용률 수집
* Root Partition 디스크 사용률 수집
* CPU 20% 초과 시 WARNING
* MEM 10% 초과 시 WARNING
* DISK 80% 초과 시 WARNING
* `/var/log/agent-app/monitor.log` 기록

## UFW 확인을 위한 최소 sudo 권한

`monitor.sh`는 `agent-admin` 계정의 cron으로 실행되기 때문에 비밀번호 입력 없이 UFW 상태를 확인할 수 있어야 한다.

전체 sudo 권한을 부여하지 않고 필요한 명령만 허용하였다.

```bash
sudo visudo
```

추가:

```text
agent-admin ALL=(root) NOPASSWD: /usr/sbin/ufw status
```

이는 필요한 명령에 대해서만 권한을 부여하는 최소 권한 원칙을 적용한 것이다.

## monitor.sh 실행

```bash
sudo -u agent-admin \
/home/agent-admin/agent-app/bin/monitor.sh
```

결과:

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

제공 애플리케이션이 CPU 부하를 증가시키는 시점에는 다음과 같이 임계값 경고도 확인하였다.

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

확인:

```bash
sudo tail -n 5 /var/log/agent-app/monitor.log
```

결과:

```text
[2026-09-08 15:04:01] PID:3071 CPU:4.8% MEM:4.8% DISK_USED:1%
[2026-09-08 15:05:01] PID:3071 CPU:4.9% MEM:4.0% DISK_USED:1%
[2026-09-08 15:06:02] PID:3071 CPU:3.3% MEM:5.0% DISK_USED:1%
[2026-09-08 15:06:23] PID:3071 CPU:6.5% MEM:4.8% DISK_USED:1%
```

프로세스 ID와 CPU, 메모리, 디스크 사용률이 요구된 형식으로 정상 기록됨을 확인하였다.

---

# 11. Logrotate 설정

`monitor.log`가 계속 증가하여 디스크 공간을 과도하게 사용하는 것을 방지하기 위해 logrotate를 적용하였다.

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

설정 의미:

```text
size 10M     : 로그 크기가 10MB 이상일 경우 회전
rotate 10    : 이전 로그 최대 10개 보관
compress     : 이전 로그 gzip 압축
missingok    : 로그 파일이 없어도 오류 처리하지 않음
notifempty   : 빈 로그는 회전하지 않음
copytruncate : 로그 복사 후 기존 파일을 비움
```

설정 검증:

```bash
sudo logrotate -d /etc/logrotate.d/agent-app
```

현재 파일이 10MB보다 작을 경우 다음과 같이 출력되었다.

```text
log does not need rotating
```

강제 회전 테스트:

```bash
sudo logrotate -f /etc/logrotate.d/agent-app
```

결과 확인:

```bash
sudo ls -lh /var/log/agent-app
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

로그 회전, 압축 및 이전 로그 보존이 정상적으로 동작함을 확인하였다.

---

# 12. Cron 자동 실행

`monitor.sh`를 `agent-admin` 계정에서 매분 실행하도록 crontab에 등록하였다.

```bash
sudo -u agent-admin crontab -e
```

등록 내용:

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
```

등록 확인:

```bash
sudo -u agent-admin crontab -l
```

자동 실행 결과:

```text
[2026-09-08 15:04:01] PID:3071 CPU:4.8% MEM:4.8% DISK_USED:1%
[2026-09-08 15:05:01] PID:3071 CPU:4.9% MEM:4.0% DISK_USED:1%
[2026-09-08 15:06:02] PID:3071 CPU:3.3% MEM:5.0% DISK_USED:1%
```

약 1분 간격으로 `monitor.log`에 새로운 데이터가 자동으로 누적되는 것을 확인하였다.

또한 logrotate를 강제로 실행한 후 새로운 `monitor.log`가 생성되었으며 이후 cron 실행을 통해:

```text
[2026-09-08 15:04:01] ...
[2026-09-08 15:05:01] ...
```

와 같이 로그 기록이 계속 이어지는 것을 확인하였다.

---

# 13. 최종 결과

이번 미션을 통해 다음 기능을 구현하고 검증하였다.

* SSH 포트를 22에서 20022로 변경
* Root SSH 원격 로그인 차단
* UFW 활성화 및 필요한 TCP 20022, 15034 포트만 허용
* 역할 기반 `agent-admin`, `agent-dev`, `agent-test` 계정 구성
* `agent-common`, `agent-core` 그룹을 이용한 최소 권한 구성
* SetGID 및 ACL을 이용한 공유/보안 디렉토리 분리
* 환경 변수를 이용한 Agent 실행 환경 구성
* 일반 계정인 `agent-admin`으로 Agent Application 실행
* Boot Sequence 5단계 `[OK]` 확인
* `0.0.0.0:15034` LISTEN 확인
* Bash 기반 `monitor.sh` 구현
* 프로세스 및 포트 Health Check 구현
* CPU/MEM/DISK 시스템 자원 수집
* 자원 임계값 초과 시 WARNING 출력
* `/var/log/agent-app/monitor.log` 자동 기록
* crontab을 이용한 매분 모니터링 자동 실행
* logrotate를 이용한 10MB/10개 로그 보존 및 압축 정책 적용

이를 통해 SSH 및 방화벽 기반 접근 보안, 역할 기반 사용자 권한 관리, 애플리케이션 실행 환경 구성, 시스템 상태 관제, 로그 기록 및 자동화까지 Linux 서버 운영의 기본적인 흐름을 직접 구성하고 검증하였다.
