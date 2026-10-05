# Ubuntu Security Hardening

Ubuntu Server의 초기 보안 상태를 진단하고 SSH, UFW, 패치, 계정 권한과 실행 서비스를 단계적으로 강화했습니다. 설정 적용 이후 정상 접근과 비정상 접근 차단을 함께 검증한 보안 엔지니어링 포트폴리오입니다.

## 프로젝트 목표

- 변경 전 상태 수집 및 위험 요소 식별
- SSH 인증 정책과 UFW 방화벽 정책 강화
- package update, 계정 권한과 실행 service 점검
- 정상 기능과 비정상 접근 차단 검증
- 설정·테스트·로그의 변경 전후 비교
- 반복 가능한 Linux 보안 점검 자동화

## 실습 환경

| 구분 | 환경 |
| --- | --- |
| Host | MacBook Air M4 |
| Virtualization | UTM |
| Server | Ubuntu Server 26.04.1 LTS |
| Web Server | nginx |
| 내부 접속 | Mac → UTM private network → Ubuntu |
| 원격 접속 | Pixel/Termius → Tailscale → Ubuntu |

## 적용한 보안 정책

### SSH

- 공개키 인증 적용
- 비밀번호 및 keyboard-interactive 인증 비활성화
- root 직접 로그인과 빈 비밀번호 로그인 차단
- 최대 인증 시도 횟수 3회 제한
- X11 forwarding 비활성화
- `sshd -t` 설정 문법 검사

자세한 설계와 검증 절차는 [SSH 하드닝 문서](docs/06_ssh_hardening.md)를 참고하세요.

### UFW

- 기본 인바운드 `deny`, 아웃바운드 `allow`
- UTM 내부망과 Tailscale 경로의 SSH·HTTP만 허용
- Tailscale 연결용 UDP 트래픽 허용
- TCP 8080 접근 차단 및 `UFW BLOCK` 로그 확인

자세한 정책과 테스트는 [UFW 하드닝 문서](docs/07_ufw_hardening.md)를 참고하세요.

### 서비스 최소화

- listening port와 담당 프로세스 확인
- modem이 없는 환경에서 `ModemManager` 비활성화
- 단일 가상 disk 환경에서 `multipathd` 비활성화
- 업데이트 가능한 firmware 장치가 없는 UTM 게스트에서 `fwupd` 예약 작업과 `udisks2` 상시 실행 제거
- UTM 복구 경로인 `serial-getty@ttyAMA0` 유지
- 재부팅 후 SSH, nginx, Tailscale, UFW 정상 동작 확인

판단 근거와 재부팅 검증은 [실행 서비스와 열린 포트 점검](docs/11_service_port_audit.md)에 정리했습니다.

### 로그와 감사

- journald 영구 저장, 압축, 200MB·30일 보존 정책 적용
- rsyslog 인증 로그 분리와 logrotate 정책 확인
- `auditd`, `audispd-plugins` 설치 및 자동 시작 확인
- 계정·sudo·SSH·UFW·audit 설정 변경 규칙 10개 적용
- 실제 파일 생성 이벤트 기록 및 `ausearch` 조회 성공
- 재부팅 후 audit 규칙 자동 적재와 이벤트 손실 없음 확인

세부 규칙과 테스트는 [시스템 로그와 감사 설정](docs/12_log_audit_hardening.md)에 정리했습니다.

### Lynis 진단 기반 추가 하드닝

- package와 kernel 보안 업데이트 적용 후 잔여 업데이트 0개 확인
- `/etc/sudoers.d` 권한 강화와 `visudo -c` 검증
- SSH forwarding·session 제한 및 상세 인증 로그 적용
- kernel 정보 노출·core dump·SysRq·BPF JIT 정책 강화
- 미사용 DCCP·SCTP·RDS·TIPC module 차단
- 비밀번호 품질·사용 기간과 기본 `umask 0027` 적용
- Lynis warning `1 → 0`, suggestion `45 → 29`, hardening index `61 → 74`

적용 항목과 보류 항목의 판단 근거는 [Lynis 진단과 추가 하드닝](docs/13_lynis_assessment.md)에 정리했습니다.

### Baseline 자동 수집

- OS, patch, 계정, 권한, SSH, UFW, port와 service 상태를 한 번에 수집
- journald·auditd와 kernel security 설정 확인
- IP, MAC 주소와 사용자 홈 경로 자동 치환
- 설정을 변경하지 않는 읽기 전용 방식
- Ubuntu Server 실제 실행과 공개 전 민감정보 검사 완료

수집 범위와 실행·검증 방법은 [보안 Baseline 자동 수집](docs/14_baseline_automation.md)에 정리했습니다.

### 보안 정책 자동 점검

- 프로젝트에서 적용한 정책을 67개 항목으로 자동 판정
- 패치, 계정, 권한, SSH, UFW, service, audit, kernel 정책 검사
- `PASS`, `FAIL`, `WARN`과 최종 요약 출력
- Ubuntu Server 실제 실행 결과 67개 전체 PASS

판정 기준과 결과 해석은 [보안 정책 자동 점검](docs/15_security_audit_automation.md)에 정리했습니다.

## 테스트 결과 요약

| 테스트 | 결과 | 상태 |
| --- | --- | --- |
| Mac 공개키 SSH | 접속 성공 | PASS |
| Pixel 공개키 SSH | 접속 성공 | PASS |
| SSH 비밀번호 인증 | `Permission denied (publickey)` | PASS |
| Mac/Pixel nginx HTTP | 페이지 표시 | PASS |
| TCP 8080 접근 | `Operation timed out` | PASS |
| UFW 차단 로그 | `UFW BLOCK`, `DPT=8080` 확인 | PASS |
| audit 설정 변경 감지 | 파일 생성 행위와 원래 로그인 사용자 기록 | PASS |
| audit 재부팅 유지 | 규칙 10개 자동 적재, `lost 0` | PASS |
| SSH 추가 정책 | effective configuration과 새 공개키 연결 확인 | PASS |
| 비밀번호 품질 | 14자 미만 시험 문자열 거부 | PASS |
| 기본 파일 권한 | 새 SSH session에서 시험 파일 `640` 확인 | PASS |
| Apport 충돌 해결 | 재부팅 후 `disabled`·`inactive`, `fs.suid_dumpable=0` | PASS |
| Lynis 재진단 | warning 0개, hardening index 74 | PASS |
| 보안 정책 자동 점검 | 67개 검사, FAIL·WARN 0개 | PASS |

SSH 유효 설정, 인증 거부, UFW 정책과 TCP 8080 차단은 `evidence/`의 실제 출력으로 확인했다. Mac과 Pixel의 일부 연결 결과는 현재 `PASS` 요약으로 정리되어 있으며 클라이언트 원시 출력은 보강 예정이다.

## 저장소 구조

```text
config-examples/   SSH·UFW·journald·auditd 설정 예시
docs/              프로젝트 설계, 환경, 테스트 및 트러블슈팅 문서
evidence/
  before/          하드닝 적용 전 실제 명령 출력
  after/           하드닝 적용 후 실제 명령 출력과 테스트 결과
reports/           최종 하드닝 보고서
scripts/           Baseline 수집 및 보안 점검 자동화
README.md           프로젝트 개요
```

Baseline 수집과 보안 정책 자동 점검 도구는 구현 및 실제 실행을 마쳤다. `reports/`의 최종 하드닝 보고서는 작업 예정이다.

## 문서

- [프로젝트 개요](docs/01_project_overview.md)
- [실습 환경](docs/02_environment.md)
- [보안 정책](docs/03_security_policy.md)
- [테스트 시나리오](docs/04_test_scenarios.md)
- [트러블슈팅](docs/05_troubleshooting.md)
- [SSH 하드닝](docs/06_ssh_hardening.md)
- [UFW 하드닝](docs/07_ufw_hardening.md)
- [시스템 업데이트 및 패치 관리](docs/08_patch_management.md)
- [사용자·계정·sudo 권한 점검](docs/09_account_sudo_audit.md)
- [중요 파일과 디렉터리 권한 점검](docs/10_file_permission_audit.md)
- [실행 서비스와 열린 포트 점검](docs/11_service_port_audit.md)
- [시스템 로그와 감사 설정](docs/12_log_audit_hardening.md)
- [Lynis 진단과 추가 하드닝](docs/13_lynis_assessment.md)
- [보안 Baseline 자동 수집](docs/14_baseline_automation.md)
- [보안 정책 자동 점검](docs/15_security_audit_automation.md)

## 다음 단계

| 작업 | 상태 |
| --- | --- |
| 시스템 업데이트 및 자동 보안 업데이트 점검 | 완료 |
| 계정·sudo 권한 점검 | 완료 |
| 중요 파일과 디렉터리 권한 점검 | 완료 |
| 실행 서비스와 열린 포트 점검 | 완료 |
| 시스템 로그와 감사 설정 점검 | 완료 |
| Lynis 변경 전후 진단 및 추가 조치 | 완료 |
| Baseline 수집 Bash 스크립트 구현 및 실제 실행 | 완료 |
| Security Audit Bash 스크립트 구현 및 실제 실행 | 완료 |
| 최종 하드닝 보고서 작성 | 작업 예정 |
