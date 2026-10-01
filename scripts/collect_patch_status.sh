#!/usr/bin/env bash

set -u

export LC_ALL=C

section() {
    printf '\n=== %s ===\n' "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

section "COLLECTION TIME"
date --iso-8601=seconds 2>/dev/null || date

section "SYSTEM"
if [[ -r /etc/os-release ]]; then
    grep -E '^(PRETTY_NAME|VERSION_ID|VERSION_CODENAME)=' /etc/os-release
else
    echo "UNAVAILABLE: /etc/os-release"
fi
uname -r
if command_exists dpkg; then
    dpkg --print-architecture
fi

section "APT PACKAGE INDEX"
if [[ -e /var/lib/apt/periodic/update-success-stamp ]]; then
    stat -c 'last successful update: %y' /var/lib/apt/periodic/update-success-stamp
elif [[ -d /var/lib/apt/lists ]]; then
    stat -c 'package lists directory modified: %y' /var/lib/apt/lists
else
    echo "UNAVAILABLE: APT package index timestamp"
fi

section "UPGRADABLE PACKAGES"
if command_exists apt; then
    apt list --upgradable 2>/dev/null
else
    echo "UNAVAILABLE: apt command"
fi

section "SIMULATED UPGRADE SUMMARY"
if command_exists apt-get; then
    apt-get --simulate upgrade 2>/dev/null | grep -E '^(Inst |Conf |[0-9]+ upgraded,|The following packages)' || true
else
    echo "UNAVAILABLE: apt-get command"
fi

section "UBUNTU SECURITY STATUS"
if command_exists ubuntu-security-status; then
    ubuntu-security-status 2>&1
else
    echo "UNAVAILABLE: ubuntu-security-status command"
fi

section "HELD PACKAGES"
if command_exists apt-mark; then
    held_packages="$(apt-mark showhold 2>/dev/null)"
    if [[ -n "$held_packages" ]]; then
        printf '%s\n' "$held_packages"
    else
        echo "none"
    fi
else
    echo "UNAVAILABLE: apt-mark command"
fi

section "DPKG AUDIT"
if command_exists dpkg; then
    dpkg_audit="$(dpkg --audit 2>&1)"
    if [[ -n "$dpkg_audit" ]]; then
        printf '%s\n' "$dpkg_audit"
    else
        echo "no partially installed packages detected"
    fi
else
    echo "UNAVAILABLE: dpkg command"
fi

section "REBOOT REQUIRED"
if [[ -e /var/run/reboot-required ]]; then
    echo "yes"
    if [[ -r /var/run/reboot-required.pkgs ]]; then
        cat /var/run/reboot-required.pkgs
    fi
else
    echo "no"
fi

section "UNATTENDED-UPGRADES PACKAGE"
if command_exists dpkg-query && dpkg-query -W -f='${Status}\n' unattended-upgrades 2>/dev/null | grep -q 'install ok installed'; then
    dpkg-query -W -f='package: ${Package}\nversion: ${Version}\nstatus: ${Status}\n' unattended-upgrades
else
    echo "not installed"
fi

section "APT UPDATE TIMERS"
if command_exists systemctl; then
    for unit in apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service; do
        enabled="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
        active="$(systemctl is-active "$unit" 2>/dev/null || true)"
        printf '%s enabled=%s active=%s\n' "$unit" "${enabled:-unknown}" "${active:-unknown}"
    done
else
    echo "UNAVAILABLE: systemctl command"
fi

section "AUTOMATIC UPDATE SETTINGS"
auto_upgrade_config=/etc/apt/apt.conf.d/20auto-upgrades
unattended_config=/etc/apt/apt.conf.d/50unattended-upgrades

if [[ -r "$auto_upgrade_config" ]]; then
    grep -E 'APT::Periodic::(Update-Package-Lists|Unattended-Upgrade)' "$auto_upgrade_config" || true
else
    echo "UNAVAILABLE: $auto_upgrade_config"
fi

if [[ -r "$unattended_config" ]]; then
    grep -E 'Unattended-Upgrade::(Allowed-Origins|Origins-Pattern|Automatic-Reboot)' "$unattended_config" || true
else
    echo "UNAVAILABLE: $unattended_config"
fi
