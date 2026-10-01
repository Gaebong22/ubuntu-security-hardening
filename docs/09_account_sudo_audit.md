# 사용자·계정·sudo 권한 점검

## 점검 목표

로그인 가능한 일반 사용자, root 계정 상태, 관리자 그룹과 sudo 권한을 확인했다. 사용하지 않는 고권한 그룹은 최소 권한 원칙에 따라 제거했다.

## 점검 결과

| 항목 | 결과 | 상태 |
| --- | --- | --- |
| 일반 사용자 | 관리자 계정 1개 | 정상 |
| root 비밀번호 | `L`(locked) | 정상 |
| 관리자 계정 | `P`(password set) | 정상 |
| sudo 권한 | `(ALL : ALL) ALL` | 의도된 관리자 권한 |
| `lxd` 그룹 | 사용자 포함 | 불필요 권한 확인 |
| LXD snap | 설치되지 않음 | `lxd` 그룹 불필요 |

## 주요 판단

root 계정은 비밀번호가 잠겨 있어 직접 비밀번호 로그인이 제한된다. 관리자 계정은 `sudo` 그룹에 속하며 서버 관리에 필요한 전체 sudo 권한을 가진다. SSH 비밀번호 인증은 비활성화되어 있고 공개키 인증을 사용한다.

관리자 계정은 `lxd` 그룹에도 포함되어 있었지만 LXD snap은 설치되지 않았다. `lxd` 그룹은 LXD 환경에서 root 수준 권한으로 이어질 수 있으므로 사용하지 않는 그룹 멤버십을 제거했다.

## 적용 내용

```bash
sudo gpasswd -d <USER> lxd
```

그룹 정보는 로그인 시 적용되므로 기존 SSH 세션을 유지한 채 새 SSH 세션을 열어 결과를 확인했다.

## 검증 결과

- `getent group lxd`: 그룹 구성원 없음
- 새 SSH 세션의 `id`: `lxd` 그룹 없음
- 공개키 SSH 재접속: 정상
- `sudo`, `adm` 등 기존 관리자 그룹: 유지

## Evidence

- Before: `evidence/before/09_account_sudo_status.txt`
- After: `evidence/after/13_account_group_hardening.txt`
