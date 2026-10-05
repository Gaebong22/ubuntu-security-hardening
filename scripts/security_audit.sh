#!/usr/bin/env bash

# Read-only policy audit for the Ubuntu security hardening lab.
#
# The script compares the current system state with controls that were applied
# and verified in this project. It does not change system configuration.

set -u
set -o pipefail

export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_VERSION="1.0.0"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    printf '[PASS] %s\n' "$1"
    ((PASS_COUNT += 1))
}

fail() {
    printf '[FAIL] %s -- %s\n' "$1" "$2"
    ((FAIL_COUNT += 1))
}

warn() {
    printf '[WARN] %s -- %s\n' "$1" "$2"
    ((WARN_COUNT += 1))
}

section() {
    printf '\n=== %s ===\n' "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_equal() {
    local label="$1"
    local actual="$2"
    local expected="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label" "expected=$expected actual=${actual:-empty}"
    fi
}

check_file_mode() {
    local path="$1"
    local expected="$2"
    local actual

    if [[ ! -e "$path" ]]; then
        fail "$path permission" "file or directory not found"
        return
    fi

    actual="$(as_root stat -c '%a %U:%G' "$path" 2>/dev/null || true)"
    check_equal "$path permission" "$actual" "$expected"
}

ROOT_AVAILABLE=0
ROOT_COMMAND=()

if (( EUID == 0 )); then
    ROOT_AVAILABLE=1
elif command_exists sudo && sudo -v; then
    ROOT_AVAILABLE=1
    ROOT_COMMAND=(sudo)
fi

as_root() {
    if (( ROOT_AVAILABLE == 1 )); then
        "${ROOT_COMMAND[@]}" "$@"
    else
        return 1
    fi
}

printf 'Ubuntu Security Audit\n'
printf 'script_version=%s\n' "$SCRIPT_VERSION"
printf 'audit_time_utc='
date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'configuration_changes=none\n'

if (( ROOT_AVAILABLE == 1 )); then
    pass "privileged checks available"
else
    warn "privileged checks unavailable" "run with sudo access for complete results"
fi

section "PATCH MANAGEMENT"
if command_exists apt; then
    upgradable="$(apt list --upgradable 2>/dev/null | sed '1d')"
    if [[ -z "$upgradable" ]]; then
        pass "no upgradable packages"
    else
        fail "no upgradable packages" "updates are available"
    fi
else
    warn "package update check" "apt not found"
fi

if command_exists dpkg; then
    dpkg_audit="$(dpkg --audit 2>&1)"
    if [[ -z "$dpkg_audit" ]]; then
        pass "dpkg database is consistent"
    else
        fail "dpkg database is consistent" "dpkg --audit returned output"
    fi
else
    warn "dpkg database check" "dpkg not found"
fi

if [[ -e /var/run/reboot-required ]]; then
    fail "reboot is not pending" "reboot-required file exists"
else
    pass "reboot is not pending"
fi

if command_exists systemctl; then
    check_equal "automatic upgrade timer enabled" \
        "$(systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null || true)" "enabled"
    check_equal "unattended-upgrades active" \
        "$(systemctl is-active unattended-upgrades.service 2>/dev/null || true)" "active"
else
    warn "automatic update services" "systemctl not found"
fi

section "ACCOUNTS AND PERMISSIONS"
if (( ROOT_AVAILABLE == 1 )) && command_exists passwd; then
    root_state="$(as_root passwd -S root 2>/dev/null | awk '{print $2}')"
    check_equal "root account is locked" "$root_state" "L"
else
    warn "root account state" "privileged passwd check unavailable"
fi

if command_exists getent; then
    lxd_members="$(getent group lxd 2>/dev/null | awk -F: '{print $4}')"
    if [[ -z "$lxd_members" ]]; then
        pass "lxd group has no members"
    else
        fail "lxd group has no members" "unexpected group membership"
    fi
else
    warn "lxd group membership" "getent not found"
fi

if (( ROOT_AVAILABLE == 1 )); then
    check_file_mode /etc/passwd "644 root:root"
    check_file_mode /etc/shadow "640 root:shadow"
    check_file_mode /etc/group "644 root:root"
    check_file_mode /etc/gshadow "640 root:shadow"
    check_file_mode /etc/sudoers "440 root:root"
    check_file_mode /etc/sudoers.d "750 root:root"

    world_writable_count="$(as_root find /etc -xdev -type f -perm -0002 -printf '.' 2>/dev/null | wc -c | tr -d ' ')"
    check_equal "no world-writable files under /etc" "$world_writable_count" "0"
else
    warn "critical file permissions" "root privileges unavailable"
fi

section "SSH"
if command_exists systemctl; then
    ssh_service_active="$(systemctl is-active ssh.service 2>/dev/null || true)"
    ssh_socket_active="$(systemctl is-active ssh.socket 2>/dev/null || true)"
    if [[ "$ssh_service_active" == "active" || "$ssh_socket_active" == "active" ]]; then
        pass "SSH service or socket is active"
    else
        fail "SSH service or socket is active" \
            "service=${ssh_service_active:-unknown} socket=${ssh_socket_active:-unknown}"
    fi
else
    warn "SSH activation state" "systemctl not found"
fi

if (( ROOT_AVAILABLE == 1 )) && command_exists sshd; then
    sshd_effective="$(as_root sshd -T 2>/dev/null || true)"

    sshd_value() {
        local key="$1"
        printf '%s\n' "$sshd_effective" | awk -v key="$key" '$1 == key {print $2; exit}'
    }

    check_equal "SSH root login disabled" "$(sshd_value permitrootlogin)" "no"
    check_equal "SSH public-key authentication enabled" "$(sshd_value pubkeyauthentication)" "yes"
    check_equal "SSH password authentication disabled" "$(sshd_value passwordauthentication)" "no"
    check_equal "SSH keyboard-interactive authentication disabled" "$(sshd_value kbdinteractiveauthentication)" "no"
    check_equal "SSH empty passwords disabled" "$(sshd_value permitemptypasswords)" "no"
    check_equal "SSH authentication attempts limited" "$(sshd_value maxauthtries)" "3"
    check_equal "SSH X11 forwarding disabled" "$(sshd_value x11forwarding)" "no"
    check_equal "SSH TCP forwarding disabled" "$(sshd_value allowtcpforwarding)" "no"
    check_equal "SSH agent forwarding disabled" "$(sshd_value allowagentforwarding)" "no"
    check_equal "SSH session count limited" "$(sshd_value maxsessions)" "2"
    check_equal "SSH verbose logging enabled" "$(sshd_value loglevel)" "VERBOSE"
else
    warn "SSH effective configuration" "privileged sshd check unavailable"
fi

section "FIREWALL AND SERVICES"
if (( ROOT_AVAILABLE == 1 )) && command_exists ufw; then
    ufw_status="$(as_root ufw status verbose 2>/dev/null || true)"
    if grep -q '^Status: active$' <<< "$ufw_status"; then
        pass "UFW is active"
    else
        fail "UFW is active" "active status not found"
    fi
    if grep -q '^Default: deny (incoming), allow (outgoing)' <<< "$ufw_status"; then
        pass "UFW default policy is deny incoming and allow outgoing"
    else
        fail "UFW default policy is deny incoming and allow outgoing" "expected policy not found"
    fi
else
    warn "UFW policy" "privileged ufw check unavailable"
fi

if command_exists systemctl; then
    for unit in nginx.service tailscaled.service auditd.service systemd-journald.service rsyslog.service; do
        check_equal "$unit is active" "$(systemctl is-active "$unit" 2>/dev/null || true)" "active"
    done

    for unit in ModemManager.service multipathd.service udisks2.service apport.service; do
        state="$(systemctl is-active "$unit" 2>/dev/null || true)"
        if [[ "$state" == "inactive" || "$state" == "unknown" ]]; then
            pass "$unit is not active"
        else
            fail "$unit is not active" "actual=${state:-empty}"
        fi
    done

    check_equal "fwupd refresh timer disabled" \
        "$(systemctl is-enabled fwupd-refresh.timer 2>/dev/null || true)" "disabled"
else
    warn "service state checks" "systemctl not found"
fi

section "LOGGING AND AUDIT"
if command_exists systemd-analyze; then
    journald_effective="$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null || true)"

    journald_value() {
        local key="$1"
        printf '%s\n' "$journald_effective" \
            | awk -F= -v key="$key" '$1 == key {value=$2} END {print value}'
    }

    check_equal "journald persistent storage enabled" "$(journald_value Storage)" "persistent"
    check_equal "journald compression enabled" "$(journald_value Compress)" "yes"
    check_equal "journald disk limit configured" "$(journald_value SystemMaxUse)" "200M"
    check_equal "journald retention configured" "$(journald_value MaxRetentionSec)" "30day"
else
    warn "journald effective configuration" "systemd-analyze not found"
fi

if (( ROOT_AVAILABLE == 1 )) && command_exists auditctl; then
    audit_status="$(as_root auditctl -s 2>/dev/null || true)"
    check_equal "Linux audit is enabled" \
        "$(awk '$1 == "enabled" {print $2}' <<< "$audit_status")" "1"
    check_equal "Linux audit lost events" \
        "$(awk '$1 == "lost" {print $2}' <<< "$audit_status")" "0"

    audit_rule_count="$(as_root auditctl -l 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$audit_rule_count" =~ ^[0-9]+$ ]] && (( audit_rule_count >= 10 )); then
        pass "audit rules loaded (count=$audit_rule_count)"
    else
        fail "audit rules loaded" "expected at least 10 actual=${audit_rule_count:-empty}"
    fi
else
    warn "Linux audit status" "privileged auditctl check unavailable"
fi

section "KERNEL AND ACCOUNT POLICY"
if command_exists sysctl; then
    check_equal "protected FIFOs hardened" "$(sysctl -n fs.protected_fifos 2>/dev/null || true)" "2"
    check_equal "setuid core dumps disabled" "$(sysctl -n fs.suid_dumpable 2>/dev/null || true)" "0"
    check_equal "kernel pointer restriction hardened" "$(sysctl -n kernel.kptr_restrict 2>/dev/null || true)" "2"
    check_equal "SysRq disabled" "$(sysctl -n kernel.sysrq 2>/dev/null || true)" "0"
    check_equal "unprivileged BPF disabled" "$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null || true)" "2"
    check_equal "BPF JIT hardening enabled" "$(as_root sysctl -n net.core.bpf_jit_harden 2>/dev/null || true)" "2"
else
    warn "kernel security parameters" "sysctl not found"
fi

login_defs_value() {
    local key="$1"
    awk -v key="$key" '$1 == key {print $2; exit}' /etc/login.defs 2>/dev/null
}

check_equal "password maximum age" "$(login_defs_value PASS_MAX_DAYS)" "365"
check_equal "password minimum age" "$(login_defs_value PASS_MIN_DAYS)" "1"
check_equal "password expiry warning" "$(login_defs_value PASS_WARN_AGE)" "14"
check_equal "password hashing method" "$(login_defs_value ENCRYPT_METHOD)" "YESCRYPT"
check_equal "default umask" "$(login_defs_value UMASK)" "027"

if [[ -r /etc/security/pwquality.conf.d/60-security-hardening.conf ]]; then
    pwquality_file=/etc/security/pwquality.conf.d/60-security-hardening.conf
    check_equal "password minimum length" \
        "$(awk -F= '$1 ~ /^[[:space:]]*minlen[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2}' "$pwquality_file")" "14"
    check_equal "password class requirement" \
        "$(awk -F= '$1 ~ /^[[:space:]]*minclass[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2}' "$pwquality_file")" "3"
    if grep -Eq '^[[:space:]]*enforce_for_root([[:space:]]|$)' "$pwquality_file"; then
        pass "password quality applies to root"
    else
        fail "password quality applies to root" "enforce_for_root not found"
    fi
else
    fail "password quality policy file" "hardening drop-in not found"
fi

for pam_file in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
    if grep -Eq '^[[:space:]]*session[[:space:]]+optional[[:space:]]+pam_umask\.so[[:space:]].*umask=0027.*nousergroups' "$pam_file" 2>/dev/null; then
        pass "$pam_file applies umask 0027"
    else
        fail "$pam_file applies umask 0027" "expected pam_umask options not found"
    fi
done

section "UNCOMMON NETWORK PROTOCOLS"
if command_exists lsmod; then
    loaded_modules="$(lsmod | awk '$1 ~ /^(dccp|sctp|rds|tipc)$/ {print $1}')"
    if [[ -z "$loaded_modules" ]]; then
        pass "unused network protocol modules are not loaded"
    else
        fail "unused network protocol modules are not loaded" "loaded modules detected"
    fi
else
    warn "loaded module check" "lsmod not found"
fi

if command_exists modprobe; then
    for module in dccp sctp rds tipc; do
        modprobe_result="$(as_root modprobe -n -v "$module" 2>&1 || true)"
        if grep -q 'install /bin/false' <<< "$modprobe_result"; then
            pass "$module load is blocked"
        else
            fail "$module load is blocked" "install /bin/false not found"
        fi
    done
else
    warn "module load policy" "modprobe not found"
fi

section "AUDIT SUMMARY"
total_count=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
printf 'total=%d\n' "$total_count"
printf 'pass=%d\n' "$PASS_COUNT"
printf 'fail=%d\n' "$FAIL_COUNT"
printf 'warn=%d\n' "$WARN_COUNT"

if (( FAIL_COUNT > 0 )); then
    echo "result=FAIL"
    exit 1
elif (( WARN_COUNT > 0 )); then
    echo "result=REVIEW"
    exit 0
else
    echo "result=PASS"
    exit 0
fi
