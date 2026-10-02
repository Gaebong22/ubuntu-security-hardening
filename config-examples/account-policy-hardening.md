# Account policy configuration example

## `/etc/login.defs`

```text
PASS_MAX_DAYS   365
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
ENCRYPT_METHOD  YESCRYPT
UMASK           027
```

`login.defs`의 기간 값은 새 계정의 기본값이다. 기존 계정에는 `chage`로 동일한 값을 별도 적용했다.

## PAM session umask

`/etc/pam.d/common-session`과 `/etc/pam.d/common-session-noninteractive`의 `pam_umask` 항목에 다음 옵션을 적용했다.

```text
session optional pam_umask.so umask=0027 nousergroups
```

`nousergroups`는 사용자명과 기본 그룹명이 같은 계정에서 group write 권한이 다시 완화되는 동작을 막는다.
