#!/usr/bin/env bash

# Read-only Ubuntu security baseline collector.
#
# The script does not change system configuration. Privileged commands are
# executed through sudo when needed. Network addresses and user home paths are
# sanitized before they are printed, but the final output must still be
# reviewed before it is added to a public repository.

set -u
set -o pipefail

export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_VERSION="1.0.0"

section() {
    printf '\n=== %s ===\n' "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

unavailable() {
    printf 'UNAVAILABLE: %s\n' "$1"
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
        unavailable "root privileges required for $1"
        return 0
    fi
}

sanitize_output() {
    sed -E \
        -e 's/([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}/<REDACTED_MAC>/g' \
        -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,3})?/<REDACTED_IP>/g' \
        -e 's#(/home/)[^/[:space:]]+#\1<REDACTED_USER>#g'
}

section "COLLECTION METADATA"
printf 'collector=collect_baseline.sh\n'
printf 'collector_version=%s\n' "$SCRIPT_VERSION"
printf 'collection_time_utc='
date -u '+%Y-%m-%dT%H:%M:%SZ'
printf 'configuration_changes=none\n'
if (( ROOT_AVAILABLE == 1 )); then
    echo "privileged_collection=available"
else
    echo "privileged_collection=unavailable"
fi

section "OPERATING SYSTEM"
if [[ -r /etc/os-release ]]; then
    grep -E '^(PRETTY_NAME|VERSION_ID|VERSION_CODENAME)=' /etc/os-release || true
else
    unavailable "/etc/os-release"
fi
printf 'kernel='
uname -r
printf 'architecture='
uname -m
if command_exists systemd-detect-virt; then
    printf 'virtualization='
    systemd-detect-virt 2>/dev/null || echo "none"
fi

section "PATCH STATUS"
if command_exists apt; then
    upgradable_packages="$(apt list --upgradable 2>/dev/null | sed '1d')"
    if [[ -n "$upgradable_packages" ]]; then
        printf '%s\n' "$upgradable_packages"
    else
        echo "upgradable_packages=none"
    fi
else
    unavailable "apt"
fi

if command_exists apt-mark; then
    held_packages="$(apt-mark showhold 2>/dev/null)"
    if [[ -n "$held_packages" ]]; then
        printf 'held_packages:\n%s\n' "$held_packages"
    else
        echo "held_packages=none"
    fi
fi

if command_exists dpkg; then
    dpkg_audit="$(dpkg --audit 2>&1)"
    if [[ -n "$dpkg_audit" ]]; then
        printf 'dpkg_audit:\n%s\n' "$dpkg_audit"
    else
        echo "dpkg_audit=clean"
    fi
fi

if [[ -e /var/run/reboot-required ]]; then
    echo "reboot_required=yes"
else
    echo "reboot_required=no"
fi

if command_exists systemctl; then
    for unit in apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service; do
        enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
        active="$(systemctl is-active "$unit" 2>/dev/null || true)"
        printf '%s enabled=%s active=%s\n' "$unit" "${enabled:-unknown}" "${active:-unknown}"
    done
fi

section "LOCAL ACCOUNTS"
if [[ -r /etc/passwd ]]; then
    awk -F: '
        $3 >= 1000 && $3 < 65534 {
            count++
            printf "regular_user_%d uid=%s gid=%s home=<REDACTED_HOME> shell=%s\n", count, $3, $4, $7
        }
        END { printf "regular_user_count=%d\n", count + 0 }
    ' /etc/passwd

    while IFS=: read -r _name _password uid gid _gecos home _shell; do
        if [[ "$uid" =~ ^[0-9]+$ ]] && (( uid >= 1000 && uid < 65534 )); then
            if [[ -d "$home" ]]; then
                stat -c 'home mode=%a uid=%u gid=%g path=<REDACTED_HOME>' "$home" 2>/dev/null || true
            fi
            if [[ -d "$home/.ssh" ]]; then
                stat -c '.ssh mode=%a uid=%u gid=%g path=<REDACTED_HOME>/.ssh' "$home/.ssh" 2>/dev/null || true
            fi
        fi
    done < /etc/passwd
else
    unavailable "/etc/passwd"
fi

if command_exists passwd; then
    as_root passwd -S root 2>&1 | sanitize_output
fi

if command_exists getent; then
    getent group sudo 2>/dev/null | awk -F: '
        {
            if ($4 == "") {
                count = 0
            } else {
                count = split($4, members, ",")
            }
            printf "sudo_member_count=%d\n", count
        }
    '
fi

section "CRITICAL FILE PERMISSIONS"
for target in \
    /etc/passwd \
    /etc/shadow \
    /etc/group \
    /etc/gshadow \
    /etc/sudoers \
    /etc/sudoers.d \
    /etc/ssh/sshd_config \
    /etc/ssh/sshd_config.d; do
    if [[ -e "$target" ]]; then
        as_root stat -c '%a %U:%G %n' "$target" 2>/dev/null || true
    else
        printf 'MISSING: %s\n' "$target"
    fi
done

if command_exists find && (( ROOT_AVAILABLE == 1 )); then
    world_writable_count="$(as_root find /etc -xdev -type f -perm -0002 -printf '.' 2>/dev/null | wc -c | tr -d ' ')"
    printf 'world_writable_files_under_etc=%s\n' "${world_writable_count:-unknown}"
elif ! command_exists find; then
    unavailable "find"
else
    unavailable "root privileges required for world-writable file check"
fi

section "SSH SERVER"
if command_exists systemctl; then
    printf 'ssh_enabled=%s\n' "$(systemctl is-enabled ssh.service 2>/dev/null || true)"
    printf 'ssh_active=%s\n' "$(systemctl is-active ssh.service 2>/dev/null || true)"
fi

if command_exists sshd; then
    as_root sshd -T 2>/dev/null \
        | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitemptypasswords|maxauthtries|x11forwarding|allowtcpforwarding|allowagentforwarding|clientaliveinterval|clientalivecountmax|maxsessions|tcpkeepalive|loglevel) ' \
        || true
else
    unavailable "sshd"
fi

section "FIREWALL"
if command_exists ufw; then
    as_root ufw status verbose 2>&1 | sanitize_output
else
    unavailable "ufw"
fi

section "LISTENING PORTS"
if command_exists ss; then
    as_root ss -H -tulpn 2>/dev/null | awk '
        {
            local_address = $5
            sub(/^.*:/, "", local_address)
            printf "%s state=%s port=%s", $1, $2, local_address
            if (NF >= 7) {
                printf " process="
                for (i = 7; i <= NF; i++) {
                    printf "%s%s", $i, (i < NF ? " " : "")
                }
            }
            printf "\n"
        }
    '
else
    unavailable "ss"
fi

section "RUNNING SERVICES"
if command_exists systemctl; then
    systemctl --type=service --state=running --no-pager --no-legend 2>/dev/null \
        | awk '{ print $1, $3, $4 }'
else
    unavailable "systemctl"
fi

section "LOGGING AND AUDIT"
if command_exists systemctl; then
    for unit in systemd-journald.service rsyslog.service auditd.service; do
        printf '%s active=%s enabled=%s\n' \
            "$unit" \
            "$(systemctl is-active "$unit" 2>/dev/null || true)" \
            "$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    done
fi

if command_exists journalctl; then
    as_root journalctl --disk-usage 2>&1 || true
    if (( ROOT_AVAILABLE == 1 )); then
        boot_count="$(as_root journalctl --list-boots --no-pager 2>/dev/null | wc -l | tr -d ' ')"
        printf 'journal_boot_count=%s\n' "${boot_count:-unknown}"
    else
        unavailable "root privileges required for boot journal count"
    fi
fi

if command_exists auditctl; then
    as_root auditctl -s 2>&1 || true
    if (( ROOT_AVAILABLE == 1 )); then
        audit_rule_count="$(as_root auditctl -l 2>/dev/null | wc -l | tr -d ' ')"
        printf 'audit_rule_count=%s\n' "${audit_rule_count:-unknown}"
    else
        unavailable "root privileges required for audit rule count"
    fi
else
    unavailable "auditctl"
fi

section "KERNEL SECURITY SETTINGS"
if command_exists sysctl; then
    as_root sysctl \
        fs.protected_fifos \
        fs.suid_dumpable \
        kernel.kptr_restrict \
        kernel.sysrq \
        kernel.unprivileged_bpf_disabled \
        net.core.bpf_jit_harden 2>&1 || true
else
    unavailable "sysctl"
fi

section "UNCOMMON NETWORK PROTOCOL MODULES"
if command_exists lsmod; then
    loaded_protocols="$(lsmod | awk '$1 ~ /^(dccp|sctp|rds|tipc)$/ { print $1 }')"
    if [[ -n "$loaded_protocols" ]]; then
        printf 'loaded:\n%s\n' "$loaded_protocols"
    else
        echo "loaded=none"
    fi
else
    unavailable "lsmod"
fi

if command_exists modprobe; then
    for module in dccp sctp rds tipc; do
        printf '%s: ' "$module"
        as_root modprobe -n -v "$module" 2>&1 \
            | tail -n 1 \
            | sanitize_output
    done
else
    unavailable "modprobe"
fi

section "SECURITY TOOL VERSIONS"
if command_exists lynis; then
    printf 'lynis='
    lynis show version 2>/dev/null || echo "unknown"
else
    echo "lynis=not_installed"
fi

if command_exists ufw; then
    ufw --version 2>/dev/null | head -n 1
fi

if command_exists auditctl; then
    auditctl -v 2>/dev/null || true
fi

section "COLLECTION RESULT"
echo "collection_complete=yes"
echo "review_required_before_publication=yes"
