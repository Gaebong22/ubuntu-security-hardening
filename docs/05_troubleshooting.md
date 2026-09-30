# 트러블슈팅

## SSH 인증 시간 초과

### 증상

개인키 passphrase 입력을 오래 기다린 뒤 서버에서 `Timeout before authentication`이 발생했습니다.

### 원인과 해결

SSH 인증 제한 시간 안에 인증이 끝나지 않은 것이 원인이었습니다. 새 연결을 시작하고 제한 시간 안에 passphrase를 입력하여 해결했습니다.

## Mac과 Ubuntu 터미널 혼동

### 증상

Mac에서 Ubuntu 프로젝트 경로나 `sudo sshd` 명령을 실행해 파일 또는 명령을 찾을 수 없었습니다.

### 원인과 해결

명령을 실행한 시스템이 달랐습니다. 프롬프트, `hostname`, `pwd`를 확인하여 Mac과 Ubuntu를 구분합니다.

- Mac: `syhong@... %`
- Ubuntu: `shinyoung@securitylab:~$`

## Pixel SSH 접속 방식 혼동

### 증상

Termius로 Ubuntu에 접속한 뒤 `user@ip` 형식을 명령처럼 입력하여 `command not found`가 발생했습니다.

### 원인과 해결

Termius는 저장된 호스트를 선택하는 순간 SSH 연결을 수행합니다. 연결 후 표시되는 터미널은 이미 원격 Ubuntu 셸이므로 별도의 `user@ip` 입력이 필요하지 않습니다.

## UFW 차단 로그가 보이지 않음

### 증상

로그 조회에서 예상한 `UFW BLOCK` 항목이 바로 나타나지 않았습니다.

### 원인과 해결

차단 대상 트래픽이 아직 발생하지 않았거나 로그 검색 범위가 제한되어 있었습니다. Mac에서 TCP 8080 연결을 다시 시도한 뒤 Ubuntu 커널 로그에서 `UFW BLOCK`과 대상 포트를 확인했습니다.

### 재확인 포인트

- UFW logging 활성화 여부
- 테스트 트래픽을 보낸 시각
- 검색한 로그의 시간 범위
- `SRC`, `DST`, `PROTO`, `SPT`, `DPT` 필드
