# 테스트 시나리오

## 테스트 원칙

- 허용된 기능의 정상 동작을 확인하는 positive test 수행
- 금지한 인증 방식과 포트 차단을 확인하는 negative test 수행
- 클라이언트 결과, 서버 설정과 차단 로그 교차 확인

## 기존 작업 기록의 결과

| ID | 테스트 | 예상 결과 | 기록된 결과 | 상태 | 연결할 evidence |
| --- | --- | --- | --- | --- | --- |
| SSH-01 | Mac 공개키 SSH | 접속 성공 | 접속 성공 | PASS | `evidence/after/01_ssh_hardening_result.txt` |
| SSH-02 | Pixel 공개키 SSH | 접속 성공 | 접속 성공 | PASS | `evidence/after/01_ssh_hardening_result.txt` |
| SSH-03 | 비밀번호 인증 | 접속 거부 | `Permission denied (publickey)` | PASS | `evidence/after/02_password_auth_disabled.txt` |
| UFW-01 | Mac nginx HTTP | HTTP 200 | 페이지 표시 | PASS | `evidence/after/03_ufw_hardening_result.txt` |
| UFW-02 | Pixel nginx HTTP | HTTP 200 | 페이지 표시 | PASS | `evidence/after/03_ufw_hardening_result.txt` |
| UFW-03 | TCP 8080 접근 | 연결 차단 | `Operation timed out` | PASS | `evidence/after/04_ufw_block_test.txt` |
| UFW-04 | 차단 로그 | `DPT=8080` | `UFW BLOCK` 확인 | PASS | `evidence/after/04_ufw_block_test.txt` |

## 증거 상태

SSH 유효 설정, 공개키 인증 로그, 비밀번호 인증 거부, UFW 정책과 TCP 8080 차단 로그를 evidence로 확인했다. Mac/Pixel의 SSH·HTTP 연결 성공은 당시 작성한 `PASS` 요약이며, client 원시 출력이 없는 항목은 최종 보고서에 증거 범위의 한계로 기록했다.

## evidence 작성 기준

1. 실행한 명령과 판정에 필요한 결과를 함께 기록한다.
2. 중복 로그는 제거하고 성공·차단 판단에 필요한 필드를 보존한다.
3. 변경 전후 evidence를 분리해 설정 차이를 비교한다.
