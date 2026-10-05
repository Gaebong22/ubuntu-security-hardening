# SSH 하드닝

## 목표

관리용 SSH 접속은 Mac과 Pixel/Termius의 공개키 인증으로 유지하면서 비밀번호 로그인, root 직접 로그인과 불필요한 전달 기능을 차단합니다.

## 적용 전 확인

1. 기존 SSH 설정과 서비스 상태를 수집합니다.
2. 현재 접속 세션을 종료하지 않은 상태에서 Mac 공개키 접속을 확인합니다.
3. Pixel/Termius 공개키 접속을 별도로 확인합니다.
4. SSH 설정 파일을 복구 가능한 위치에 백업합니다.

## 적용 정책

적용 설정은 `config-examples/sshd-hardening.conf`에 정리했다.

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
```

## 안전한 적용 순서

1. 공개키 인증이 실제로 성공하는지 먼저 확인합니다.
2. 하드닝 설정을 반영합니다.
3. `sudo sshd -t`로 문법을 검사합니다.
4. 검사에 성공한 경우에만 SSH 서비스를 reload 또는 restart합니다.
5. 기존 세션을 유지하고 새 터미널에서 공개키 접속을 확인합니다.
6. Mac과 Pixel에서 각각 접속을 확인한 후 기존 세션을 종료합니다.

`sshd -t` 통과 후 SSH 서비스를 다시 불러오고 `active` 상태를 확인했다.

## 검증 결과

Mac과 Pixel의 공개키 접속, 비밀번호 인증 거부, `sshd -t` 검사와 서비스 상태 확인을 완료했다. 비밀번호 인증 테스트 결과는 `Permission denied (publickey)`였다.

`evidence/after/01_ssh_hardening_result.txt`에는 유효 SSH 설정, 서비스 `active` 상태와 공개키 인증 성공 로그를 저장했다. `evidence/after/02_password_auth_disabled.txt`에는 비밀번호 전용 인증 명령과 거부 결과를 기록했다. Pixel 연결 성공은 당시 작성한 PASS 요약이며 개별 client 인증 로그는 남아 있지 않다.

## 확인해야 할 evidence

- 적용 전 유효 SSH 설정
- 적용 후 유효 SSH 설정
- `sshd -t` 결과 및 종료 상태
- SSH 서비스 상태
- Mac·Pixel 공개키 접속 결과
- 비밀번호 인증 거부 결과
