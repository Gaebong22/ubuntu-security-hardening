# 보안 정책

## SSH 정책

| 설정 | 값 | 목적 |
| --- | --- | --- |
| `PermitRootLogin` | `no` | root 직접 로그인 차단 |
| `PubkeyAuthentication` | `yes` | 공개키 기반 인증 사용 |
| `PasswordAuthentication` | `no` | 비밀번호 추측 공격 표면 축소 |
| `KbdInteractiveAuthentication` | `no` | keyboard-interactive 우회 인증 차단 |
| `PermitEmptyPasswords` | `no` | 빈 비밀번호 계정 로그인 차단 |
| `MaxAuthTries` | `3` | 연결당 인증 시도 횟수 제한 |
| `X11Forwarding` | `no` | 사용하지 않는 전달 기능 비활성화 |

정책 적용 전 Mac과 Pixel의 공개키 로그인을 확인했고, 설정 백업 후 `sshd -t` 문법 검사를 수행했다. 세부 과정은 [SSH 하드닝](06_ssh_hardening.md)에 정리했다.

## UFW 정책

| 구분 | 정책 |
| --- | --- |
| 기본 inbound | `deny` |
| 기본 outbound | `allow` |
| SSH | UTM 내부망 및 Tailscale 경로만 허용 |
| HTTP | UTM 내부망 및 Tailscale 경로만 허용 |
| Tailscale UDP | 연결 유지에 필요한 범위만 허용 |
| 그 외 inbound | 명시적으로 허용하지 않으면 차단 |

최소 권한 원칙에 따라 필요한 출발지·포트·프로토콜만 허용했다. 세부 과정은 [UFW 하드닝](07_ufw_hardening.md)에 정리했다.
