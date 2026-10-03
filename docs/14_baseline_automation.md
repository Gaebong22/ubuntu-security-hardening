# 보안 Baseline 자동 수집

## 목적

`scripts/collect_baseline.sh`는 하드닝이 적용된 Ubuntu Server의 주요 보안 상태를 한 번에 수집하는 읽기 전용 Bash 스크립트다. 반복 점검 시 같은 명령과 출력 형식을 사용해 누락을 줄이고, 현재 상태를 이전 evidence와 비교할 수 있도록 작성했다.

스크립트는 설정을 변경하지 않는다. 권한이 필요한 조회 명령을 위해 시작할 때 `sudo` 인증을 요청할 수 있으며, 수집 결과는 공개 전에 다시 검토하도록 마지막에 안내한다.

## 수집 항목

- OS, kernel, architecture와 가상화 환경
- 업데이트 가능·보류 package, `dpkg` 상태와 재부팅 필요 여부
- 일반 사용자 수, 관리자 그룹과 주요 디렉터리 권한
- 주요 system file 및 설정 디렉터리 권한
- SSH service·socket 상태와 effective configuration
- UFW 정책과 허용 rule
- listening port와 실행 중인 service
- journald, rsyslog, auditd 상태와 audit rule 수
- 주요 kernel security parameter
- DCCP, SCTP, RDS, TIPC module 차단 상태
- Lynis, UFW 등 보안 도구 version

## 실행 방법

저장소 최상위에서 다음과 같이 실행한다.

```bash
./scripts/collect_baseline.sh > evidence/after/24_automated_baseline.txt
```

- `./scripts/collect_baseline.sh`: 현재 디렉터리의 수집 스크립트를 실행한다.
- `>`: 화면에 출력될 내용을 지정한 파일에 새로 저장한다. 같은 이름의 파일이 있으면 덮어쓰므로 경로를 먼저 확인해야 한다.

공개 저장소에 넣기 전에는 오류와 민감정보 후보를 별도로 확인한다.

```bash
grep -niE 'UNAVAILABLE|MISSING|error|failed|denied|NOTICE' evidence/after/24_automated_baseline.txt
```

`grep`은 일치하는 줄을 찾으며, `-n`은 줄 번호, `-i`는 대소문자 무시, `-E`는 여러 검색 조건을 사용하는 확장 정규식을 뜻한다. 출력이 없으면 해당 문자열이 발견되지 않았다는 의미다.

## 공개용 출력 처리

수집 과정에서 IPv4 주소, MAC 주소와 사용자 홈 경로는 placeholder로 치환한다. 사용자 이름 대신 UID·GID와 계정 수를 기록해 환경 고유 정보의 노출을 줄였다.

자동 치환 후에도 결과 파일을 검토해 환경 식별 정보가 남아 있지 않은지 확인한다.

## 검증 결과

Ubuntu Server에서 실제 실행해 14개 영역, 160줄의 결과를 수집했다. 실행 오류와 누락 표시가 없었고 실제 IP 주소, MAC 주소와 사용자 홈 경로도 검사에서 발견되지 않았다.

초기 시험에서는 `/etc/passwd`의 field를 잘못 나누어 UID 위치에 password placeholder가 들어가는 문제가 있었다. 7개 field를 각각 읽도록 수정하고 숫자 UID만 처리하도록 검증 조건을 추가한 뒤 다시 실행해 정상 완료했다.

Ubuntu의 SSH는 `ssh.socket`을 통한 socket activation을 사용한다. 따라서 `ssh.service`가 `disabled`여도 service가 `active`이고 `ssh.socket`이 `enabled`·`active`이면 재부팅 후 연결을 받을 수 있는 정상 상태다. 수집 결과에는 service와 socket 상태를 함께 기록해 이 차이를 확인할 수 있게 했다.

## Evidence

- After: `evidence/after/24_automated_baseline.txt`
