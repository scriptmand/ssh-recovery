#!/bin/bash

echo "=== SSH RECOVERY SCRIPT ==="

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo
echo "=== SYSTEM INFO ==="
hostname
echo
locale

if command -v localectl >/dev/null 2>&1; then
    echo
    localectl status
fi

# Enable SSH
echo
echo "=== ENABLING SSH ==="

systemctl enable ssh 2>/dev/null
systemctl start ssh 2>/dev/null

# Backup sshd_config
echo
echo "=== BACKING UP SSH CONFIG ==="

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F-%H%M%S)

# Configure SSH
echo
echo "=== CONFIGURING SSH ==="

grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config || \
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config || \
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config || \
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Validate SSH configuration
echo
echo "=== VALIDATING SSH CONFIG ==="

if sshd -t; then
    systemctl restart ssh
    echo "SSH configuration OK."
else
    echo "ERROR: Invalid SSH configuration."
    exit 1
fi

echo
echo "=== SSH STATUS ==="

systemctl is-active ssh
ss -tulpn | grep ssh

# UFW
if command -v ufw >/dev/null 2>&1; then
    echo
    echo "=== UFW FOUND ==="

    ufw allow 22/tcp >/dev/null 2>&1
    ufw reload >/dev/null 2>&1

    ufw status
fi

# IPTABLES
if command -v iptables >/dev/null 2>&1; then
    echo
    echo "=== IPTABLES FOUND ==="

    iptables -I INPUT -p tcp --dport 22 -j ACCEPT

    iptables -L INPUT -n | grep ":22"
fi

# FAIL2BAN
if systemctl is-active --quiet fail2ban; then
    echo
    echo "=== FAIL2BAN FOUND ==="

    fail2ban-client status

    echo
    echo "Currently banned SSH IPs:"

    fail2ban-client status sshd 2>/dev/null
fi

# ROOT ACCOUNT STATUS
echo
echo "=== ROOT ACCOUNT STATUS ==="

passwd -S root

echo
echo "=== FINAL CHECK ==="

grep -E 'PasswordAuthentication|PubkeyAuthentication|PermitRootLogin' /etc/ssh/sshd_config

echo
echo "=== RECOVERY COMPLETE ==="

echo "Test SSH with:"
echo "ssh root@SERVER_IP"
