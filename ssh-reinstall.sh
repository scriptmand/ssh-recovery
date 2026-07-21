#!/bin/bash

echo "=== SSH Reinstallation & Recovery Script ==="

# Stop socket activation if present
systemctl stop ssh.socket 2>/dev/null
systemctl disable ssh.socket 2>/dev/null

# Stop SSH service
systemctl stop ssh 2>/dev/null

# Backup existing configuration
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%F-%H%M%S)
    echo "[OK] Backup created."
fi

# Remove and reinstall OpenSSH
apt-get purge openssh-server -y
apt-get autoremove -y
apt-get update
apt-get install openssh-server -y

# Create runtime directory if missing
mkdir -p /run/sshd
chmod 755 /run/sshd

# Configure SSH settings
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Add settings if missing
grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
grep -q '^PubkeyAuthentication' /etc/ssh/sshd_config || echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

# Validate SSH configuration
echo
echo "=== Validating SSH configuration ==="

if sshd -t; then
    echo "[OK] SSH configuration is valid."
else
    echo "[ERROR] SSH configuration is invalid."
    exit 1
fi

# Enable and start SSH
systemctl daemon-reload
systemctl enable ssh
systemctl start ssh
systemctl restart ssh

echo
echo "=== Verification ==="

systemctl --no-pager --full status ssh | head -15

echo
echo "Listening ports:"
ss -tulpn | grep ssh

echo
echo "SSH version:"
ssh -V

echo
echo "[SUCCESS] SSH reinstallation completed."
