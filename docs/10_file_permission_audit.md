# 중요 파일과 디렉터리 권한 점검

## 점검 목표

계정, sudo, SSH 설정과 사용자 SSH 디렉터리의 소유권·권한을 확인했다. 시스템 설정 파일이 일반 사용자에게 수정되거나 민감한 계정 정보가 노출될 수 있는지 함께 점검했다.

## 점검 결과

| 대상 | 권한 | 소유자 | 판정 |
| --- | --- | --- | --- |
| `/etc/passwd`, `/etc/group` | `644` | `root:root` | 정상 |
| `/etc/shadow`, `/etc/gshadow` | `640` | `root:shadow` | 정상 |
| `/etc/sudoers` | `440` | `root:root` | 정상 |
| `/etc/ssh/sshd_config` | `644` | `root:root` | 정상 |
| `sudoers.d`, `sshd_config.d` | `755` | `root:root` | 정상 |
| 사용자 홈 | `750` | 사용자 소유 | 정상 |
| 사용자 `.ssh` | `700` | 사용자 소유 | 정상 |
| SSH 인증 파일 | `600` | 사용자 소유 | 정상 |
| `/tmp`, `/var/tmp` | `1777` | `root:root` | 정상 |

`sudoers.d`와 `sshd_config.d`의 추가 설정 파일도 모두 root 소유였으며 일반 사용자에게 쓰기 권한이 없었다.

## World-writable 파일 검사

`/etc` 아래에서 모든 사용자가 수정할 수 있는 파일을 검색했다.

```bash
sudo find /etc -xdev -type f -perm -0002 -print
```

검색 결과가 없어 world-writable 시스템 설정 파일은 발견되지 않았다.

## 결론

점검 대상의 권한과 소유권은 안전한 범위로 설정되어 있었다. 별도의 권한 변경은 적용하지 않았다.

## Evidence

- `evidence/before/10_file_permission_audit.txt`
