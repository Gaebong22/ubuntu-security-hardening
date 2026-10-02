# 실습 환경

## 구성 요소

| 구분 | 내용 |
| --- | --- |
| Host | MacBook Air M4 |
| Virtualization | UTM |
| Server | Ubuntu Server 26.04.1 LTS |
| Web Server | nginx |
| 로컬 관리 단말 | Mac |
| 원격 관리 단말 | Pixel, Termius |
| 원격 네트워크 | Tailscale |

## 접속 경로

```text
Mac ── UTM private network ──> Ubuntu Server

Pixel/Termius ── Tailscale ──> Ubuntu Server
```

두 경로 모두 SSH 관리 접속과 nginx HTTP 확인에 사용했다.

## 작업 위치 구분

- Mac 프롬프트 예시: `<REDACTED_USER>@... %`
- Ubuntu 프롬프트 예시: `<REDACTED_USER>@securitylab:~$`
- Ubuntu 프로젝트 경로: `~/linux-security-hardening`

명령 실행 전 프롬프트와 `hostname`, `pwd`로 현재 시스템을 구분했다.
