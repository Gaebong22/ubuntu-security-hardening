# 시스템 업데이트 및 패치 관리

## 진단 목표

운영체제와 설치 패키지의 업데이트 상태를 확인하고 보안 업데이트가 자동으로 적용될 수 있는지 점검한다. 진단 단계에서는 패키지를 설치하거나 서비스를 재시작하지 않는다.

## 점검 항목

| 항목 | 확인 내용 | 현재 상태 |
| --- | --- | --- |
| 패키지 인덱스 | `apt update` 성공 여부 | 정상 갱신 |
| 업그레이드 대상 | 설치 가능한 패키지 목록 | 20개 적용, 잔여 0개 |
| 실행 kernel | `uname -r` | `7.0.0-34-generic` |
| 보류 패키지 | `apt-mark showhold` | 없음 |
| 패키지 일관성 | `dpkg --audit` | 이상 없음 |
| 재부팅 필요 여부 | `/var/run/reboot-required` | 재부팅 후 해제 |
| 자동 업데이트 | 패키지·timer·설정 상태 | 설치 및 활성화 확인 |

## 변경 전 상태 수집

먼저 패키지 인덱스를 갱신한다. 이 명령은 설치 가능한 최신 버전 정보를 내려받지만 패키지 자체를 업그레이드하지 않는다.

```bash
cd ~/linux-security-hardening
sudo apt update
```

갱신이 끝나면 읽기 전용 진단 스크립트를 실행한다.

```bash
bash scripts/collect_patch_status.sh \
  | tee evidence/before/08_patch_status.txt
```

스크립트는 다음 정보를 수집한다.

- OS·kernel·architecture
- APT package index 시각
- 업그레이드 가능한 패키지
- `apt-get --simulate upgrade` 결과
- Ubuntu security status
- held package와 `dpkg --audit` 결과
- 재부팅 필요 여부
- `unattended-upgrades` 패키지, timer와 주요 설정

## 판정 기준

| 결과 | 판정 |
| --- | --- |
| 보안 업데이트 없음, `dpkg --audit` 이상 없음 | 양호 |
| 보안 업데이트 존재 | 패치 적용 필요 |
| held package 존재 | 보류 사유 확인 필요 |
| `dpkg --audit` 출력 존재 | 패키지 상태 복구 필요 |
| `reboot-required` 존재 | 유지보수 시간에 재부팅 필요 |
| 자동 업데이트 미설치 또는 비활성화 | 설정 검토 필요 |

## 적용 결과

변경 전 evidence에서 20개 패키지의 업데이트와 재부팅 필요 상태를 확인했다. `apt upgrade`로 전체 패키지를 적용했으며, APT history에서 이전 버전과 적용 버전을 확인했다.

재부팅 후 새 kernel과 주요 서비스를 다시 검증했다.

| 검증 항목 | 결과 | 상태 |
| --- | --- | --- |
| Mac 공개키 SSH | 재접속 성공 | PASS |
| 실행 kernel | `7.0.0-34-generic` | PASS |
| UFW | `active`, 기존 정책 유지 | PASS |
| nginx service | `active` | PASS |
| Mac HTTP | `HTTP/1.1 200 OK` | PASS |
| 잔여 업데이트 | 없음 | PASS |
| 추가 재부팅 | 불필요 | PASS |
| `dpkg --audit` | 출력 없음 | PASS |
| held package | 없음 | PASS |

`unattended-upgrades` 패키지와 timer는 이미 활성화되어 있었으며, APT history에서도 자동 업데이트 실행 기록을 확인했다. 별도의 설정 변경은 필요하지 않았다.

## Evidence

- Before: `evidence/before/08_patch_status.txt`
- APT history: `evidence/after/08_apt_upgrade_history.txt`
- SSH·kernel: `evidence/after/09_reboot_ssh_kernel_check.txt`
- UFW: `evidence/after/10_post_reboot_ufw_status.txt`
- nginx·HTTP: `evidence/after/11_post_reboot_nginx_check.txt`
- 패키지 최종 상태: `evidence/after/12_post_upgrade_package_status.txt`
