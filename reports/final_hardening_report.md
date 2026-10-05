# Ubuntu Server Security Hardening 최종 보고서

## 1. 프로젝트 요약

UTM에서 실행하는 Ubuntu Server를 대상으로 초기 보안 상태를 진단하고 SSH, 방화벽, 패치, 계정 권한, 서비스, 로그와 kernel 정책을 단계적으로 강화했다. 각 변경은 적용 전 상태 수집, 설정 백업, 변경, 정상 기능 확인, 차단 테스트와 재부팅 후 검증 순서로 진행했다.

최종적으로 Lynis warning은 1개에서 0개로 감소했고 hardening index는 61에서 74로 상승했다. 자체 보안 점검 스크립트로 프로젝트 정책 67개를 다시 검사한 결과는 `67 PASS, 0 FAIL, 0 WARN`이었다.

## 2. 범위와 환경

| 구분 | 내용 |
| --- | --- |
| Host | MacBook Air M4 |
| Virtualization | UTM/QEMU |
| Server | Ubuntu Server 26.04.1 LTS, aarch64 |
| 최종 kernel | `7.0.0-38-generic` |
| Web service | nginx |
| 관리 경로 | UTM private network, Tailscale |
| 주요 도구 | OpenSSH, UFW, auditd, Lynis, Bash |

대상은 단일 실습 서버다. nginx는 HTTP 기능 검증용이며 외부 공개 production service는 범위에 포함하지 않았다.

## 3. 초기 진단 결과

| 영역 | 확인된 상태 | 위험 또는 개선 필요성 |
| --- | --- | --- |
| SSH | 비밀번호 인증 허용, `MaxAuthTries 6`, X11 forwarding 허용 | 계정 공격 표면과 불필요 기능 축소 필요 |
| 방화벽 | UFW 비활성 | listening service에 대한 host firewall 통제 부재 |
| 패치 | 업데이트 대상과 재부팅 필요 상태 존재 | 보안 update 적용 및 kernel 교체 필요 |
| 계정 | 미사용 `lxd` 그룹 멤버십 존재 | 불필요한 고권한 경로 제거 필요 |
| 서비스 | 사용하지 않는 modem·multipath·disk·firmware 관련 service 실행 | 상시 실행 요소 최소화 필요 |
| 감사 | journald와 rsyslog는 동작, auditd 미설치 | 중요 설정 변경의 행위자 추적 보강 필요 |
| Lynis | warning 1개, suggestion 45개, index 61 | 환경에 맞는 추가 hardening 검토 필요 |

## 4. 적용한 보안 통제

### 4.1 SSH

- 공개키 인증 유지
- root 직접 로그인, 비밀번호와 keyboard-interactive 인증 차단
- 최대 인증 시도 3회, session 2개로 제한
- X11, TCP, agent forwarding 차단
- `ClientAliveInterval 300`, `ClientAliveCountMax 2` 적용
- `TCPKeepAlive no`, `LogLevel VERBOSE` 적용
- `sshd -t`와 effective configuration으로 문법 및 적용값 확인

### 4.2 UFW

- 기본 인바운드 `deny`, 아웃바운드 `allow`
- UTM private network와 Tailscale 경로의 SSH·HTTP만 허용
- Tailscale 연결에 필요한 UDP traffic 허용
- logging을 활성화하고 미허용 TCP 8080 차단 확인

### 4.3 패치와 계정

- APT update 적용 및 최신 kernel로 재부팅
- 잔여 update, held package와 `dpkg --audit` 이상 없음 확인
- `unattended-upgrades`와 관련 timer 활성 상태 확인
- 미사용 `lxd` 그룹 멤버십 제거
- root password 잠금과 관리자 sudo 권한 확인

### 4.4 권한과 서비스 최소화

- 계정·sudo·SSH 관련 파일과 디렉터리 권한 점검
- `/etc/sudoers.d`를 `750 root:root`로 강화
- `/etc` 아래 world-writable 일반 파일이 없음을 확인
- `ModemManager`, `multipathd`, `udisks2` 비활성화
- update 가능한 firmware device가 없어 `fwupd-refresh.timer` 비활성화
- UTM 복구에 사용하는 `serial-getty@ttyAMA0`은 유지

### 4.5 로그와 감사

- journald 영구 저장, 압축, 최대 200MB와 30일 보존 설정
- rsyslog 인증 로그 분리와 logrotate 확인
- auditd와 audispd plugin 설치
- 계정, sudo, SSH, UFW, audit 설정 변경을 감시하는 rule 10개 적용
- 시험 파일 생성 이벤트에서 `uid`, `auid`, syscall과 audit key 확인

### 4.6 Kernel과 계정 정책

- `fs.protected_fifos=2`, `fs.suid_dumpable=0`
- `kernel.kptr_restrict=2`, `kernel.sysrq=0`
- `kernel.unprivileged_bpf_disabled=2`, `net.core.bpf_jit_harden=2`
- 사용하지 않는 DCCP, SCTP, RDS, TIPC module load 차단
- 비밀번호 최소 14자와 문자 종류 3개 이상 적용
- 비밀번호 최소 1일, 최대 365일, 만료 14일 전 경고
- YESCRYPT 유지 및 로그인 session 기본 `umask 0027` 적용

## 5. 주요 변경 전후 비교

| 항목 | Before | After |
| --- | --- | --- |
| SSH password authentication | `yes` | `no` |
| SSH root login | `prohibit-password` | `no` |
| SSH 최대 인증 시도 | 6 | 3 |
| SSH X11 forwarding | `yes` | `no` |
| UFW | `inactive` | `active`, deny incoming |
| 미사용 LXD 권한 | 관리자 계정 포함 | 구성원 없음 |
| auditd | 미설치 | active, rule 10개 |
| kernel update | update 필요 | `7.0.0-38-generic`, 잔여 update 없음 |
| Lynis warning | 1 | 0 |
| Lynis suggestion | 45 | 29 |
| Lynis hardening index | 61 | 74 |

## 6. 검증 결과

| 검증 | 실제 결과 | 판정 |
| --- | --- | --- |
| Mac·Pixel 공개키 SSH | 두 경로 모두 연결 성공 | PASS |
| 비밀번호 전용 SSH | `Permission denied (publickey)` | PASS |
| nginx HTTP | Mac·Pixel 표시, 서버에서 `HTTP/1.1 200 OK` | PASS |
| 미허용 TCP 8080 | client timeout, `UFW BLOCK DPT=8080` | PASS |
| 재부팅 후 필수 service | SSH, nginx, Tailscale, auditd, logging active | PASS |
| audit event | 설정 경로의 생성 행위와 원래 로그인 사용자 기록 | PASS |
| audit 재부팅 유지 | rule 10개, `lost 0`, `backlog 0` | PASS |
| 비밀번호 품질 | 14자 미만 시험 문자열 거부 | PASS |
| 기본 파일 생성 권한 | 새 SSH session의 시험 파일 `640` | PASS |
| 자동 정책 점검 | 67 PASS, 0 FAIL, 0 WARN | PASS |

## 7. 자동화

`scripts/collect_baseline.sh`는 OS, patch, 계정, 권한, SSH, UFW, service, audit와 kernel 상태를 동일한 형식으로 수집한다. 실제 실행 결과는 14개 영역 160줄이며 환경 식별 정보가 남지 않도록 출력값을 정리했다.

`scripts/security_audit.sh`는 이 프로젝트에서 적용한 통제를 기대값과 비교한다. `PASS`, `FAIL`, `WARN`을 구분하며 하나 이상의 실패가 있으면 종료 code `1`을 반환한다. 최종 실행에서는 67개 검사가 모두 통과했다.

## 8. 주요 트러블슈팅

| 문제 | 원인 | 해결 |
| --- | --- | --- |
| APT Release file 시간 오류 | VM 시간이 약 2일 느림 | `chronyc makestep` 후 package index 갱신 |
| udisks2 재활성화 | fwupd가 D-Bus로 udisks2 요청 | 장치 필요성을 확인하고 fwupd timer 비활성화 |
| `fs.suid_dumpable` 값 복귀 | Apport 시작 script가 값을 2로 변경 | 실습 서버에서 Apport 비활성화 후 재부팅 검증 |
| audit watch 경고 | 기존 `-w` 형식 사용 | syscall 기반 `-a always,exit` 규칙으로 교체 |
| Baseline 첫 실행 오류 | `/etc/passwd` field parsing 오류 | 7개 field 분리와 숫자 UID 검사 추가 |

## 9. 보류 항목과 한계

- `/home`, `/var` 별도 partition은 신규 VM 구축 시 반영할 항목으로 남겼다.
- GRUB password와 `kernel.modules_disabled=1`은 복구 복잡도 때문에 적용하지 않았다.
- Tailscale policy routing 영향을 고려해 strict `rp_filter`는 일괄 적용하지 않았다.
- nginx HTTPS와 외부 log server는 내부 단일 lab 범위를 넘어 별도 확장 과제로 남겼다.
- `loginuid_immutable`은 향후 운영·container 요구를 확인한 뒤 적용해야 한다.
- Mac과 Pixel의 일부 성공 결과는 client 원시 출력이 아니라 당시 작성한 PASS 요약으로 남아 있다. SSH 인증 거부, UFW 차단과 주요 server-side 설정은 별도 원시 evidence로 확인했다.
- 자동 점검의 PASS는 이 프로젝트가 정한 통제가 유지됨을 뜻하며 모든 취약점의 부재나 보안 인증을 의미하지 않는다.

## 10. Evidence와 문서

- 초기 상태: `evidence/before/`
- 적용 및 검증 결과: `evidence/after/`
- 자동 Baseline: `evidence/after/24_automated_baseline.txt`
- 자동 정책 점검: `evidence/after/25_security_audit.txt`
- 세부 설계와 분석: `docs/06_ssh_hardening.md`부터 `docs/15_security_audit_automation.md`
- 재현 가능한 설정 예시: `config-examples/`

## 11. 결론

초기 진단에서 확인한 원격 접근, host firewall, patch, 불필요 권한과 서비스, 감사 공백을 실제 설정 변경과 테스트로 개선했다. 정상 기능만 확인하지 않고 비밀번호 인증과 미허용 port가 차단되는지도 검증했으며, 재부팅 이후 정책 유지 여부를 다시 확인했다.

마지막으로 상태 수집과 정책 판정을 Bash로 자동화해 같은 기준으로 반복 점검할 수 있게 했다. 이 저장소는 진단, 위험 판단, 안전한 적용, 기능·차단 검증과 운영상 보류 판단까지 포함한 Ubuntu Server hardening 사례다.
