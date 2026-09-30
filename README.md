# Ubuntu Security Hardening

Ubuntu Server의 초기 보안 상태를 진단하고 SSH와 UFW를 중심으로 보안 설정을 강화했습니다. 또한 설정 적용 이 후 정상 접근과 비정상 접근 차단을 함께 검증한 보안 엔지니어링 포트폴리오입니다.

## 프로젝트 목표

- 변경 전 상태 수집 및 위험 요소 식별
- SSH 인증 정책과 UFW 방화벽 정책 강화
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

## 테스트 결과 요약

| 테스트 | 결과 | 상태 |
| --- | --- | --- |
| Mac 공개키 SSH | 접속 성공 | PASS |
| Pixel 공개키 SSH | 접속 성공 | PASS |
| SSH 비밀번호 인증 | `Permission denied (publickey)` | PASS |
| Mac/Pixel nginx HTTP | 페이지 표시 | PASS |
| TCP 8080 접근 | `Operation timed out` | PASS |
| UFW 차단 로그 | `UFW BLOCK`, `DPT=8080` 확인 | PASS |

SSH 유효 설정, 인증 거부, UFW 정책과 TCP 8080 차단은 `evidence/`의 실제 출력으로 확인했다. Mac과 Pixel의 일부 연결 결과는 현재 `PASS` 요약으로 정리되어 있으며 클라이언트 원시 출력은 보강 예정이다.

## 저장소 구조

```text
config-examples/   SSH·UFW 설정 예시
docs/              프로젝트 설계, 환경, 테스트 및 트러블슈팅 문서
evidence/
  before/          하드닝 적용 전 실제 명령 출력
  after/           하드닝 적용 후 실제 명령 출력과 테스트 결과
reports/           최종 하드닝 보고서
scripts/           Baseline 수집 및 보안 점검 자동화
README.md           프로젝트 개요
```

`reports/`의 최종 보고서와 `scripts/`의 자동 진단 도구는 작업 예정이다.

## 문서

- [프로젝트 개요](docs/01_project_overview.md)
- [실습 환경](docs/02_environment.md)
- [보안 정책](docs/03_security_policy.md)
- [테스트 시나리오](docs/04_test_scenarios.md)
- [트러블슈팅](docs/05_troubleshooting.md)
- [SSH 하드닝](docs/06_ssh_hardening.md)
- [UFW 하드닝](docs/07_ufw_hardening.md)

## 다음 단계

| 작업 | 상태 |
| --- | --- |
| 시스템 업데이트 및 자동 보안 업데이트 점검 | 작업 예정 |
| 계정·sudo·파일 권한·실행 서비스 점검 | 작업 예정 |
| Lynis 변경 전후 진단 및 추가 조치 | 작업 예정 |
| Baseline·Security Audit Bash 스크립트 구현 | 작업 예정 |
| 최종 하드닝 보고서 작성 | 작업 예정 |
