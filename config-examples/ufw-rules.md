# UFW Firewall Rules

## 기본 정책

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

## 허용 규칙 예시

`<UTM_PRIVATE_SUBNET>`은 실습 환경의 UTM 내부망 CIDR로 변경한다.

```bash
# UTM 내부망에서 SSH와 HTTP 허용
sudo ufw allow from <UTM_PRIVATE_SUBNET> to any port 22 proto tcp
sudo ufw allow from <UTM_PRIVATE_SUBNET> to any port 80 proto tcp

# Tailscale 인터페이스에서 SSH와 HTTP 허용
sudo ufw allow in on tailscale0 to any port 22 proto tcp
sudo ufw allow in on tailscale0 to any port 80 proto tcp
```

Tailscale 연결용 UDP 규칙은 실제 사용 포트와 네트워크 구성을 확인한 뒤 최소 범위로 추가한다. 원격 서버에서는 SSH 허용 규칙을 먼저 적용하고 새 세션 연결을 확인한 후 UFW를 활성화한다.
