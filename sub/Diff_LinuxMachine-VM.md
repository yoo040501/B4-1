## OrbStack Linux Machine과 Docker/VM 차이

이번 과제에서는 Docker 컨테이너 대신 OrbStack Linux Machine을 사용하였다.

Docker 컨테이너는 일반적으로 하나의 애플리케이션이나 서비스를 격리하여 실행하는 환경이다. 컨테이너 내부에서는 `systemd`, SSH 서버, cron, UFW와 같은 시스템 서비스를 일반 Linux 서버처럼 운영하기에 제약이 있을 수 있다.

반면 OrbStack Linux Machine은 독립적인 Linux 환경을 제공하며 `systemd`를 사용할 수 있다. 따라서 사용자/그룹 관리, SSH, UFW, cron, ACL, logrotate와 같은 Linux 서버 운영 기능을 일반적인 Ubuntu 환경과 유사하게 실습할 수 있다.

일반 VM과 비교하면 OrbStack Linux Machine은 더 가볍고 macOS와의 파일 시스템 및 네트워크 연동이 편리하다. 반면 VMware나 VirtualBox와 같은 일반 VM은 가상 CPU, 메모리, 디스크, 네트워크 장치를 포함한 전체 운영체제를 보다 독립적으로 실행한다.

간단히 구분하면 다음과 같다.

* Docker Container: 특정 애플리케이션 실행과 배포에 적합
* OrbStack Linux Machine: 가벼운 Linux 개발 및 서버 실습 환경에 적합
* 일반 VM: 실제 독립 서버와 유사한 전체 OS 가상화에 적합

이번 과제에서는 SSH 포트 변경, UFW 방화벽 설정, 계정/그룹 및 ACL 관리, cron 자동 실행 등의 기능이 필요했기 때문에 Docker 컨테이너보다 OrbStack Linux Machine이 더 적합하다고 판단하였다.
