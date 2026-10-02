# 시스템 로그와 감사 설정

## 점검 목표

재부팅 후에도 시스템 로그가 보존되는지 확인하고, 로그 파일의 권한과 회전 정책을 점검했다. 중요 보안 설정의 변경 주체를 추적하기 위해 Linux Audit을 설치하고 최소 감사 규칙을 적용했다.

## 초기 상태

| 항목 | 결과 | 판단 |
| --- | --- | --- |
| `systemd-journald` | `active` | 정상 |
| `rsyslog` | `active` | 정상 |
| journal 부팅 기록 | 이전 부팅 4개와 현재 부팅 보존 | persistent 저장 확인 |
| journal 사용량 | 36.3MB | 디스크 압박 없음 |
| journal 파일 | `640 root:systemd-journal` | 일반 사용자 접근 제한 |
| `/var/log/auth.log` | `640 syslog:adm` | 인증 로그 권한 정상 |
| rsyslog 회전 | weekly, 4개 보관, 압축 | 약 4주 보관 |
| `auditd` | 미설치 | 보안 설정 변경 추적 미구성 |

## journald 보존 정책

기본 설정으로도 이전 부팅 로그가 남아 있었지만 용량과 기간 제한을 명시하기 위해 drop-in을 추가했다.

```ini
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=200M
SystemKeepFree=1G
MaxRetentionSec=30day
```

전체 journal은 최대 200MB 또는 30일 중 먼저 도달한 조건에 따라 정리된다. root filesystem에는 최소 1GB의 여유 공간을 남긴다. Ubuntu의 `ForwardToSyslog=yes` 설정도 유지해 journal 이벤트가 rsyslog로 전달되도록 했다.

## Linux Audit 구성

`auditd`와 `audispd-plugins`를 설치한 뒤 다음 영역에 10개 규칙을 적용했다.

| Key | 감시 대상 | 기록 조건 |
| --- | --- | --- |
| `identity` | `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow` | 쓰기·속성 변경 |
| `sudo_policy` | `/etc/sudoers`, `/etc/sudoers.d/` | 쓰기·속성 변경 |
| `sshd_config` | `/etc/ssh/sshd_config`, `/etc/ssh/sshd_config.d/` | 쓰기·속성 변경 |
| `firewall_config` | `/etc/ufw/` | 쓰기·속성 변경 |
| `audit_config` | `/etc/audit/` | 쓰기·속성 변경 |

ARM64 native syscall에 맞춰 `arch=b64`를 지정했다. 단일 파일에는 `path=`, 하위 경로를 포함하는 디렉터리에는 `dir=`을 사용했다.

전체 예시는 [`config-examples/audit-hardening.rules`](../config-examples/audit-hardening.rules)에서 확인할 수 있다.

## 기능 테스트

`/etc/audit/audit-test.tmp`를 생성한 뒤 `ausearch`로 이벤트를 조회했다.

```text
proctitle=touch /etc/audit/audit-test.tmp
nametype=CREATE
syscall=openat
success=yes
uid=root
auid=<REDACTED_USER>
key=audit_config
```

`uid=root`는 `sudo`로 실행된 실제 권한이고, `auid`는 처음 로그인한 사용자를 나타낸다. 따라서 관리자 권한으로 실행한 변경도 원래 사용자를 기준으로 추적할 수 있다. 테스트 파일은 확인 후 삭제했다.

## 규칙 문법 개선

처음에는 `-w` watch 규칙을 사용했지만 적용 과정에서 `Old style watch rules are slower` 경고가 발생했다. 동일한 감시 범위를 syscall 기반 `-a always,exit`와 `path`·`dir` 형식으로 교체한 뒤 경고 없이 적재했다.

`auditctl` 매뉴얼에서도 `-w` 형식은 성능상의 이유로 deprecated이며 syscall 기반 형식을 권장한다: [auditctl(8)](https://man7.org/linux/man-pages/man8/auditctl.8.html)

## 재부팅 후 검증

- `systemd-journald`, `rsyslog`, `auditd`: `active`
- audit 규칙: 10개 자동 적재
- audit 상태: `enabled 1`
- 손실 이벤트: `lost 0`
- 대기 이벤트: `backlog 0`
- 공개키 SSH 재접속: 성공

## 남은 판단

현재 `loginuid_immutable`은 `unlocked` 상태다. audit 규칙을 완전히 잠그는 설정은 변경 시 재부팅이 필요하고 향후 container 또는 운영 방식에 영향을 줄 수 있어 프로젝트 구성 단계에서는 적용하지 않았다. 최종 Lynis 결과와 운영 요구를 함께 검토한 뒤 적용 여부를 결정한다.

## Evidence

- Before: `evidence/before/13_log_audit_baseline.txt`
- After: `evidence/after/22_log_audit_hardening.txt`
