# 보안 정책 자동 점검

## 목적

`scripts/security_audit.sh`는 이 프로젝트에서 적용한 보안 정책이 현재도 유지되는지 자동으로 판정한다. Baseline 수집기가 시스템 상태를 기록하는 도구라면, 이 스크립트는 실제 값을 기대값과 비교해 `PASS`, `FAIL`, `WARN`으로 표시한다.

설정을 변경하지 않는 읽기 전용 점검이며, root 권한이 필요한 항목을 위해 실행 초기에 `sudo` 인증을 요청할 수 있다.

## 판정 범위

| 영역 | 주요 검사 항목 |
| --- | --- |
| 패치 관리 | 잔여 업데이트, `dpkg` 상태, 재부팅 필요 여부, 자동 업데이트 |
| 계정과 권한 | root 잠금, LXD 그룹, 중요 파일과 디렉터리 권한 |
| SSH | 인증 방식, root 로그인, forwarding, session과 log 정책 |
| 방화벽과 서비스 | UFW 기본 정책, 필수 서비스, 비활성화한 서비스 |
| 로그와 감사 | journald 보존, audit 활성 상태, 이벤트 손실, rule 수 |
| Kernel | core dump, pointer 노출, SysRq, BPF 관련 설정 |
| 계정 정책 | 비밀번호 기간·품질, YESCRYPT, 기본 `umask` |
| Kernel module | DCCP, SCTP, RDS, TIPC 미적재 및 load 차단 |

검사 기준은 Lynis 제안을 그대로 복사하지 않고, 이 서버에서 실제 적용한 정책과 환경별 판단을 기준으로 구성했다. 보류한 항목은 실패로 판정하지 않는다.

## 실행 방법

저장소 최상위에서 다음과 같이 실행한다.

```bash
./scripts/security_audit.sh
```

결과를 evidence로 저장하려면 출력 redirection을 사용한다.

```bash
./scripts/security_audit.sh > evidence/after/25_security_audit.txt
```

`>`는 기존 파일을 새 결과로 교체하므로 대상 경로를 확인한 뒤 실행한다.

## 결과 해석

- `PASS`: 실제 값이 이 프로젝트의 기대값과 일치한다.
- `FAIL`: 실제 값이 기대값과 다르거나 필수 조건을 확인하지 못했다.
- `WARN`: 도구 또는 권한이 없어 일부 검사를 완료하지 못했다.

마지막 요약에는 전체 검사 수와 판정별 개수, 최종 결과가 출력된다. 하나 이상의 `FAIL`이 있으면 최종 결과는 `FAIL`이고 종료 code는 `1`이다. `WARN`만 있으면 검토가 필요하다는 의미로 `REVIEW`, 실패와 경고가 모두 없으면 `PASS`가 된다.

## 실제 검증 결과

Ubuntu Server에서 root 권한을 포함해 실제 실행한 결과 67개 검사 전체가 통과했다.

```text
total=67
pass=67
fail=0
warn=0
result=PASS
```

결과 파일에서 `[FAIL]`과 `[WARN]` 항목이 없음을 추가 확인했고, 공개 전 환경 식별 정보 검사도 통과했다.

이 결과는 특정 시점의 시스템 상태와 프로젝트 정책을 비교한 것이다. 일반적인 보안 인증이나 모든 취약점의 부재를 의미하지 않으며, SSH 실제 접속과 UFW 차단 같은 동작 검증은 별도의 positive·negative test evidence로 보완한다.

## Evidence

- After: `evidence/after/25_security_audit.txt`
