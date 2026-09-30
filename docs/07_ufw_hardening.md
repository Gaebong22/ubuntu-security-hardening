# UFW 방화벽 하드닝

## 목표

기본 인바운드 트래픽을 차단하고 관리 및 서비스 운영에 필요한 SSH, HTTP, Tailscale 통신만 최소 범위로 허용합니다.

## 적용 전 확인

1. 현재 UFW 상태와 등록된 규칙을 수집합니다.
2. `ss` 등의 도구로 실제 리스닝 포트를 확인합니다.
3. Mac과 Pixel이 사용하는 접속 경로와 source network를 확인합니다.
4. SSH 허용 규칙을 UFW 활성화보다 먼저 추가합니다.
5. 콘솔 또는 기존 SSH 세션 등 복구 경로를 유지합니다.

## 정책 설계

```text
default incoming: deny
default outgoing: allow

UTM private network -> TCP 22: allow
UTM private network -> TCP 80: allow
Tailscale path      -> TCP 22: allow
Tailscale path      -> TCP 80: allow
Tailscale UDP       -> required traffic only: allow
all other inbound   -> deny
```

적용 명령은 `config-examples/ufw-rules.md`에 정리했다. UTM subnet과 Tailscale UDP 포트는 서버 구성에서 확인한 값을 사용했다.

## 검증 결과

다음 항목을 확인했다.

- Mac과 Pixel에서 SSH 연결 성공
- Mac과 Pixel에서 nginx HTTP 페이지 표시
- 미허용 TCP 8080 연결은 `Operation timed out`
- Ubuntu 커널 로그에서 `UFW BLOCK`과 `DPT=8080` 확인

`evidence/after/03_ufw_hardening_result.txt`에는 UFW 기본 정책·허용 규칙·리스닝 포트와 연결 테스트 결과를 저장했다. `evidence/after/04_ufw_block_test.txt`에는 TCP 8080 테스트 명령과 `UFW BLOCK` 로그를 기록했다. Mac/Pixel의 SSH·HTTP 클라이언트 원시 출력은 보강 예정이다.

## 로그에서 확인할 필드

| 필드 | 의미 |
| --- | --- |
| `SRC` | source IP |
| `DST` | destination IP |
| `PROTO` | protocol |
| `SPT` | 임시 source port |
| `DPT` | 접근을 시도한 destination port |

차단 여부는 `UFW BLOCK`, `PROTO=TCP`, `DPT=8080`을 기준으로 확인했다.

## 주의사항

- SSH 허용 규칙을 먼저 적용한 뒤 UFW를 활성화했다.
- HTTP 정상 응답과 미허용 포트 차단을 별도로 확인했다.
- 클라이언트 timeout 결과와 서버 차단 로그를 함께 비교했다.
