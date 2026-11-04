#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "[-] L'installation doit être lancée en tant que root." >&2
    exit 1
fi

echo "[+] Installation des paquets de sécurité..."
apt-get update && apt-get install -y fail2ban nftables rsync

echo "[+] Application des configurations de sécurité..."
mkdir -p /etc/ssh/sshd_config.d/
cp config/ssh/sshd_config.d/hardening.conf /etc/ssh/sshd_config.d/
systemctl restart ssh

mkdir -p /etc/fail2ban/jail.d/
cp config/fail2ban/jail.d/sshd.conf /etc/fail2ban/jail.d/
systemctl enable fail2ban
systemctl restart fail2ban

cp config/nftables.conf /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables

cp config/journald.conf /etc/systemd/journald.conf
systemctl restart systemd-journald

echo "[+] Installation et configuration terminées avec succès !"
