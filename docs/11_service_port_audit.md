# 실행 서비스와 열린 포트 점검

## 점검 목표

실행 중인 서비스와 listening port를 함께 확인해 실제 용도가 없는 상시 프로세스를 줄였다. 서비스를 비활성화하기 전에는 장치와 의존 관계를 확인했고, 변경 후에는 재부팅하여 원격 관리와 웹 서비스가 정상 동작하는지 검증했다.

## 열린 포트 점검

`ss -tulpn`으로 프로토콜, 수신 주소, port와 담당 프로세스를 확인했다.

| Port | 프로세스 | 용도 | 판단 |
| --- | --- | --- | --- |
| TCP 22 | `sshd` | SSH 원격 관리 | 유지 |
| TCP 80 | `nginx` | HTTP 테스트 서비스 | 유지 |
| UDP 41641 | `tailscaled` | Tailscale 직접 연결 | 유지 |
| TCP/UDP 53 | `systemd-resolved` | 로컬 DNS resolver | loopback 전용, 유지 |
| UDP 68 | `systemd-networkd` | DHCP client | 네트워크 설정에 필요 |
| UDP 323 | `chronyd` | 시간 동기화 제어 | loopback 전용, 유지 |
| Tailscale 임시 TCP port | `tailscaled` | Tailscale peer 연결 | 유지 |

예상하지 않은 외부 listening port는 발견되지 않았다. 서비스 변경 후 다시 수집한 목록에서도 SSH, HTTP, Tailscale과 로컬 시스템 port만 확인됐다.

## 서비스 검토 결과

| 서비스 | 확인 내용 | 조치 |
| --- | --- | --- |
| `ModemManager` | 연결된 modem 없음 | `disable --now` |
| `multipathd` | multipath device 없음, 단일 UTM 가상 disk 사용 | `disable --now` |
| `udisks2` | GUI display manager 미사용 | `disable --now` |
| `fwupd-refresh.timer` | QEMU 장치만 식별되며 업데이트 가능한 장치 없음 | 예약 실행 비활성화 |
| `serial-getty@ttyAMA0` | `ttyAMA0`이 active kernel console | 복구 경로로 유지 |

패키지는 제거하지 않았다. 필요성이 생기면 서비스를 다시 활성화할 수 있도록 설정 변경만 적용했다.

## udisks2 재활성화 원인 분석

`udisks2`를 비활성화한 뒤 첫 재부팅에서는 서비스가 다시 `active` 상태가 됐다. `disabled`는 target에 연결된 자동 시작을 막지만 D-Bus 요청까지 차단하는 설정은 아니다.

해당 시각의 journal을 확인한 결과 다음 순서로 실행됐다.

```text
fwupd-refresh.service
  → fwupd.service
    → D-Bus 요청
      → udisks2.service
```

`fwupdmgr get-updates` 결과는 `No updatable devices`였다. UTM 게스트 안에서 정기 firmware metadata 갱신의 실효성이 없어 `fwupd-refresh.timer`를 비활성화하고 현재 실행 중인 `fwupd`와 `udisks2`를 중지했다. `udisks2`를 `mask`하지 않아 수동 복구 가능성과 다른 요청 경로는 남겨 뒀다.

추후 USB passthrough 등 firmware update가 필요한 장치를 VM에 연결한다면 `fwupd-refresh.timer`를 다시 활성화하고 지원 장치를 재점검해야 한다.

## 재부팅 후 검증

두 번째 재부팅 후 다음 결과를 확인했다.

- `ModemManager`, `multipathd`, `udisks2`, `fwupd`: `inactive`
- 위 세 service와 `fwupd-refresh.timer`: `disabled`
- `ssh`, `nginx`, `tailscaled`, `serial-getty@ttyAMA0`: `active`
- 공개키 SSH 재접속: 성공
- UFW: `active`, 기본 인바운드 `deny` 유지
- nginx: `HTTP/1.1 200 OK`
- 적용 가능한 package update: 0개

## Evidence

- Before: `evidence/before/11_listening_ports.txt`
- Before: `evidence/before/12_running_services.txt`
- After: `evidence/after/14_modemmanager_disabled.txt`
- After: `evidence/after/15_multipathd_disabled.txt`
- After: `evidence/after/16_udisks2_disabled.txt`
- After: `evidence/after/17_serial_console_retained.txt`
- After: `evidence/after/18_running_services_after.txt`
- After: `evidence/after/19_listening_ports_after.txt`
- After: `evidence/after/20_fwupd_udisks2_followup.txt`
- After: `evidence/after/21_service_hardening_validation.txt`
