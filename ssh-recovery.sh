#!/bin/bash

echo "========================================="
echo " LINUX SSH RECOVERY TOOL"
echo "========================================="

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

echo
echo "=== SYSTEM INFORMATION ==="

hostname
echo

if command -v localectl >/dev/null 2>&1; then
    localectl status
fi

echo
echo "=== ENABLE SSH ==="

systemctl enable ssh 2>/dev/null
systemctl start ssh 2>/dev/null

echo
echo "=== BACKUP CONFIGURATION ==="

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)

for file in /etc/ssh/sshd_config.d/*.conf
do
    [ -f "$file" ] || continue
    cp "$file" "$file.bak.$(date +%Y%m%d-%H%M%S)"
done

echo
echo "=== FIX MAIN SSH CONFIG ==="

sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

echo
echo "=== FIX OVERRIDE FILES ==="

for file in /etc/ssh/sshd_config.d/*.conf
do
    [ -f "$file" ] || continue

    echo "Checking: $file"

    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$file"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$file"
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$file"
done

echo
echo "=== VALIDATE SSH CONFIG ==="

if sshd -t; then
    echo "SSH CONFIG OK"
else
    echo "SSH CONFIG ERROR"
    exit 1
fi

echo
echo "=== RESTART SSH ==="

systemctl restart ssh

echo
echo "=== DETECT SSH PORT ==="

SSH_PORT=$(sshd -T | awk '/^port / {print $2}' | head -1)

if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
fi

echo "Detected SSH Port: $SSH_PORT"

echo
echo "=== UFW CHECK ==="

if command -v ufw >/dev/null 2>&1; then
    ufw allow ${SSH_PORT}/tcp >/dev/null 2>&1
    ufw reload >/dev/null 2>&1

    echo
    ufw status
fi

echo
echo "=== IPTABLES CHECK ==="

if command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport ${SSH_PORT} -j ACCEPT

    iptables -L INPUT -n | grep ":${SSH_PORT}"
fi

echo
echo "=== FAIL2BAN STATUS ==="

if command -v fail2ban-client >/dev/null 2>&1; then
    fail2ban-client status

    echo

    fail2ban-client status sshd 2>/dev/null
fi

echo
echo "=== ROOT ACCOUNT STATUS ==="

passwd -S root

echo
echo "=== SSH SERVICE STATUS ==="

systemctl is-active ssh

echo
echo "=== SSH LISTENING ==="

ss -tulpn | grep ssh

echo
echo "=== EFFECTIVE SSH SETTINGS ==="

sshd -T | grep permitrootlogin
sshd -T | grep passwordauthentication
sshd -T | grep pubkeyauthentication

echo
echo "=== LOCAL TEST ==="

nc -zv localhost ${SSH_PORT} 2>/dev/null

echo
echo "========================================="
echo " RECOVERY COMPLETE"
echo "========================================="
echo
echo "Test SSH using:"
echo "ssh root@SERVER_IP"
echo

sleep 2
echo "[INFO] Self-deleting script..."

rm -f "$0"
