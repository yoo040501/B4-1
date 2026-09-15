# UFW와 firewalld 차이

UFW와 firewalld는 모두 리눅스에서 방화벽 정책을 쉽게 관리하기 위한 도구이다.  
둘 다 실제 패킷 필터링 기능 자체를 직접 구현하는 것이 아니라, Linux 커널의 Netfilter 기반 방화벽 기능을 보다 쉽게 설정하도록 도와주는 관리 도구에 가깝다.

---

## 1. 주요 차이

| 구분 | UFW | firewalld |
|---|---|---|
| 의미 | Uncomplicated Firewall | Firewall Daemon |
| 주 사용 환경 | Ubuntu / Debian 계열 | RHEL / CentOS / Fedora 계열 |
| 설정 방식 | 단순한 규칙 중심 | Zone 기반 |
| 난이도 | 비교적 쉬움 | 조금 더 복잡 |
| 동적 변경 | 가능하지만 단순 | 동적 정책 변경에 강점 |
| 네트워크 구분 | 비교적 단순 | Zone별로 세밀하게 관리 가능 |
| 주요 명령어 | `ufw` | `firewall-cmd` |

---

## 2. UFW

UFW는 이름 그대로 복잡한 방화벽 설정을 단순하게 만들기 위한 도구이다.

예를 들어 이번 과제에서는 SSH 포트와 애플리케이션 포트만 허용하였다.

```bash
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp
sudo ufw enable
```

설정 확인:

```bash
sudo ufw status
```

Ubuntu 환경에서 소수의 포트만 허용하는 단순한 서버 방화벽 정책을 구성할 때 사용하기 편하다.

---

## 3. firewalld

firewalld는 `zone` 개념을 사용하여 네트워크 환경별로 서로 다른 방화벽 정책을 적용할 수 있다.

대표적인 zone 예:

```text
public
internal
trusted
dmz
```

예를 들어 public zone에서 TCP 20022 포트를 허용하려면 다음과 같이 설정할 수 있다.

```bash
sudo firewall-cmd --zone=public --add-port=20022/tcp --permanent
sudo firewall-cmd --reload
```

설정 확인:

```bash
sudo firewall-cmd --list-all
```

---

## 4. Zone을 사용하는 이유

서버에 여러 네트워크 인터페이스가 있을 경우, 네트워크 종류에 따라 서로 다른 정책을 적용할 수 있다.

예:

```text
인터넷 연결 NIC
    ↓
public zone
    ↓
SSH 등 필요한 외부 서비스만 허용

사내망 NIC
    ↓
internal zone
    ↓
DB, 관리 포트 등 내부 서비스 추가 허용
```

따라서 firewalld는 네트워크 구성이 복잡한 서버 환경에서 유리하다.

---

## 5. 실제 동작 구조

UFW와 firewalld는 실제 방화벽 기능 자체가 아니라 관리 도구이다.

대략적인 구조는 다음과 같다.

```text
UFW / firewalld
       ↓
nftables / iptables
       ↓
Linux Kernel Netfilter
       ↓
실제 패킷 허용 / 차단
```

Linux 커널의 Netfilter가 실제 패킷 필터링을 수행하고, UFW와 firewalld는 이를 사람이 쉽게 설정할 수 있도록 도와준다.

---

## 6. 이번 과제에서 UFW를 선택한 이유

이번 과제는 Ubuntu 환경에서 진행했고, 필요한 인바운드 포트가 다음 두 개뿐이었다.

```text
20022/tcp : SSH
15034/tcp : Agent Application
```

복잡한 zone 구성이 필요하지 않았기 때문에 설정과 검증이 간단한 UFW가 적합하다고 판단하였다.

면접이나 발표에서는 다음과 같이 설명할 수 있다.

> Ubuntu 환경이었고, SSH 20022와 애플리케이션 15034처럼 소수의 포트만 허용하는 단순한 정책이 필요했기 때문에 설정과 검증이 간단한 UFW를 사용했습니다.
