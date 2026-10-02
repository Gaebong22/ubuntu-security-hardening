# Lynis 진단과 추가 하드닝

## 진단 목표

Lynis를 root 권한으로 실행해 기존 설정을 제3의 점검 기준으로 확인했다. 점수를 높이는 것 자체보다 실제 위험, 서버 용도와 복구 가능성을 기준으로 조치 항목을 선택했다.

Ubuntu 저장소의 `lynis 3.1.6`을 사용했으며 자동 실행 timer는 비활성화했다. Before와 After 진단은 모두 다음 명령으로 수동 실행했다.

```bash
sudo lynis audit system --quick
```

## 진단 결과 비교

| 항목 | Before | After | 변화 |
| --- | ---: | ---: | ---: |
| Warning | 1 | 0 | -1 |
| Suggestion | 45 | 29 | -16 |
| Hardening index | 61 | 74 | +13 |
| Tests performed | 267 | 267 | 동일 |

초기 warning은 업데이트가 필요한 package가 있다는 `PKGS-7392`였다. kernel과 OpenSSL 보안 업데이트를 적용하고 `7.0.0-38-generic`으로 재부팅한 뒤 잔여 업데이트가 없음을 확인했다. 재진단에서는 warning이 제거됐다.

## 적용한 개선 사항

### sudo와 SSH

- `/etc/sudoers.d` 권한을 `755`에서 `750`으로 제한
- `visudo -c` 문법 검사 통과
- 사용하지 않는 TCP·agent forwarding 차단
- `ClientAliveInterval 300`, `ClientAliveCountMax 2` 적용
- `MaxSessions 2`, `TCPKeepAlive no`, `LogLevel VERBOSE` 적용
- `sshd -t`, effective configuration, 새 공개키 SSH 연결로 검증

일반 SSH와 SCP는 유지되지만 SSH tunnel 또는 일부 remote development 기능이 필요해지면 forwarding 정책을 다시 검토해야 한다.

### 커널과 네트워크 프로토콜

다음 값을 `/etc/sysctl.d/60-security-hardening.conf`에 적용했다.

```text
fs.protected_fifos = 2
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.sysrq = 0
net.core.bpf_jit_harden = 2
```

재부팅 후 `fs.suid_dumpable`만 `2`로 돌아오는 문제가 있었다. 설정 파일 충돌은 없었고, `apport.service`의 시작 스크립트가 값을 `2`로 변경하는 것을 확인했다. 자동 crash report가 필요하지 않은 실습 서버이므로 Apport를 비활성화했다. 다시 재부팅한 뒤에도 서비스는 `disabled`·`inactive`, 값은 `0`으로 유지됐다.

현재 사용하지 않는 `DCCP`, `SCTP`, `RDS`, `TIPC`는 modprobe의 `install /bin/false`와 `blacklist`를 함께 사용해 로드를 차단했다. Tailscale 등 다른 기능에서도 사용할 수 있는 공용 `udp_tunnel` 모듈은 차단하지 않았다.

### 비밀번호와 기본 파일 권한

- `libpam-pwquality` 설치
- 최소 14자, 문자 종류 3개 이상, 반복·연속 문자열 제한
- 사전 단어와 사용자 정보 포함 여부 검사
- root 권한의 비밀번호 변경에도 품질 정책 적용
- 비밀번호 최소 1일, 최대 365일, 만료 14일 전 경고
- 로그인 session의 기본 `umask`를 `0027`로 강화

약한 공개 시험 문자열은 14자 미만으로 거부됐고, 새 SSH session에서 생성한 시험 파일은 `640`으로 확인한 뒤 삭제했다.

## 적용하지 않은 주요 제안

| 제안 | 판단 |
| --- | --- |
| `/home`, `/var` 별도 partition | 기존 단일 VM disk를 다시 분할해야 하므로 신규 구축 시 반영 |
| GRUB password | UTM console 복구 복잡도가 증가해 실습 환경에서는 보류 |
| SSH port 변경 | 공격 차단의 핵심 통제가 아니며 UFW source 제한과 공개키 인증을 우선 |
| `fail2ban` | 비밀번호 인증 차단, UTM subnet 제한, Tailscale 접근으로 추가 효과가 제한적 |
| nginx HTTPS | 민감 데이터를 다루지 않는 내부 demo이며 인증서·도메인 범위 밖 |
| 외부 log host | 별도 log server가 없는 독립 lab이므로 로컬 영구 보존과 auditd로 대체 |
| SHA hashing rounds | 현재 `YESCRYPT`를 사용하므로 `SHA_CRYPT_*_ROUNDS`를 임의 적용하지 않음 |
| strict `rp_filter` | Tailscale과 policy routing에 영향을 줄 수 있어 일괄 적용하지 않음 |
| `kernel.modules_disabled=1` | 적용 후 재부팅 전 복구가 어렵고 module 운영에 영향을 주므로 보류 |
| compiler 제한 | 향후 Bash·보안 도구 실습과 package build 가능성을 위해 유지 |
| malware scanner·file integrity tool | 다음 확장 단계에서 운영 비용과 탐지 범위를 설계한 뒤 검토 |

Lynis suggestion은 취약점 확정 목록이 아니라 추가 검토 항목이다. 환경에 맞지 않는 설정까지 일괄 적용하지 않고, 보류 사유를 기록하는 방식으로 처리했다.

## 최종 검증

- 공개키 SSH 재접속 성공
- `ssh`, `nginx`, `tailscaled`, `auditd`, `journald`, `rsyslog`: `active`
- UFW: `active`, 기본 인바운드 `deny`
- nginx: `HTTP/1.1 200 OK`
- audit rule 10개 적재, `lost 0`, `backlog 0`
- 재부팅 후 Apport `disabled`·`inactive`, `fs.suid_dumpable = 0`
- Lynis warning 0개, hardening index 74

## Evidence

- Before: `evidence/before/14_lynis_initial_summary.txt`
- After: `evidence/after/23_lynis_hardening_result.txt`
