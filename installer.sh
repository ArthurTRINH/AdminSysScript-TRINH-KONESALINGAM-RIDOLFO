#!/bin/bash
# installer.sh - configure toute la Debian a partir du depot
# Usage : sudo ./installer.sh      (relancable sans danger, ne formate jamais de disque)
# 1er passage : comptes et services. Ensuite : sudo passwd <admin>, tester ssh + sudo, puis relancer.
# Garde-fous : SSH n'est configure que si un admin a une cle ;
#              root n'est verrouille que si un admin a un mot de passe.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV="$REPO/comptes.csv"
SAUV_DIR=/sauvegardes
NB_ATTENTION=0

attention() { echo "[ATTENTION] $*"; NB_ATTENTION=$((NB_ATTENTION + 1)); }

# logins du CSV dont le groupe principal ou secondaire est $1
logins_du_groupe() {
    tail -n +2 "$CSV" | tr -d '\r' | awk -F';' -v g="$1" \
        'NF == 4 && ($3 == g || ("," $4 ",") ~ ("," g ",")) { print $1 }'
}

# vrai si un admin (membre de acces_ssh) a une cle SSH installee
admin_avec_cle() {
    local a home
    for a in $(logins_du_groupe admins); do
        id -nG "$a" | tr ' ' '\n' | grep -qx acces_ssh || continue
        home="$(getent passwd "$a" | cut -d: -f6)"
        if [[ -s $home/.ssh/authorized_keys ]]; then return 0; fi
    done
    return 1
}

# vrai si un admin a un mot de passe (statut P)
admin_avec_mdp() {
    local a
    for a in $(logins_du_groupe admins); do
        if [[ $(passwd -S "$a" | awk '{print $2}') == P ]]; then return 0; fi
    done
    return 1
}

[[ $EUID -eq 0 ]] || { echo "[ERREUR] Lancer avec sudo" >&2; exit 1; }

for f in creer_comptes.sh comptes.csv analyse_logs.sh sauvegarde.sh \
         config/ssh/sshd_config.d/00-hardening.conf config/nftables.conf \
         config/fail2ban/jail.d/sshd.conf config/journald.conf \
         config/sudoers.d/admins config/sudoers.d/support config/apt/20auto-upgrades \
         config/systemd/sauvegarde.service config/systemd/sauvegarde.timer; do
    [[ -f $REPO/$f ]] || { echo "[ERREUR] Fichier manquant dans le depot : $f" >&2; exit 1; }
done

echo "==== 1. Paquets ===="
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q acl sudo openssh-server openssh-client fail2ban python3-systemd \
    nftables rsync unattended-upgrades

echo "==== 2. Scripts dans /usr/local/sbin ===="
# root:root 0755 : support lance analyse_logs.sh en root, il ne doit pas pouvoir le modifier
install -m 0755 -o root -g root "$REPO/analyse_logs.sh" /usr/local/sbin/analyse_logs.sh
install -m 0755 -o root -g root "$REPO/sauvegarde.sh" /usr/local/sbin/sauvegarde.sh

echo "==== 3. Comptes, groupes, /srv, ACL ===="
bash "$REPO/creer_comptes.sh" "$CSV"
chmod 0700 /home/*/
sed -i '/^#\?[[:space:]]*HOME_MODE/d' /etc/login.defs
echo "HOME_MODE 0700" >> /etc/login.defs        # futurs comptes : home en 0700

echo "==== 4. sudo ===="
for f in admins support; do
    visudo -cqf "$REPO/config/sudoers.d/$f"      # verifie la syntaxe avant d'installer
    install -m 0440 -o root -g root "$REPO/config/sudoers.d/$f" "/etc/sudoers.d/$f"
done

echo "==== 5. Journal persistant ===="
install -d -m 0755 /etc/systemd/journald.conf.d
install -m 0644 "$REPO/config/journald.conf" /etc/systemd/journald.conf.d/99-chiffres-co.conf
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal || true
systemctl restart systemd-journald
journalctl --flush || true

echo "==== 6. Mises a jour automatiques ===="
install -m 0644 "$REPO/config/apt/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer

echo "==== 7. Pare-feu nftables ===="
nft -c -f "$REPO/config/nftables.conf"           # verifie la syntaxe sans appliquer
install -m 0755 -o root -g root "$REPO/config/nftables.conf" /etc/nftables.conf
systemctl enable nftables
# reload et pas restart : l'arret du service efface aussi les bans de fail2ban
if systemctl is-active -q nftables; then systemctl reload nftables; else systemctl start nftables; fi

echo "==== 8. fail2ban ===="
install -m 0644 "$REPO/config/fail2ban/jail.d/sshd.conf" /etc/fail2ban/jail.d/sshd.conf
fail2ban-client -t >/dev/null
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban

echo "==== 9. Sauvegardes ===="
install -m 0644 "$REPO/config/systemd/sauvegarde.service" /etc/systemd/system/sauvegarde.service
install -m 0644 "$REPO/config/systemd/sauvegarde.timer" /etc/systemd/system/sauvegarde.timer
systemctl daemon-reload
if ! blkid -L SAUVEGARDES >/dev/null 2>&1; then
    attention "Aucun disque SAUVEGARDES : lancer 'sudo ./preparer_disque.sh /dev/sdb' puis relancer installer.sh"
else
    install -d -m 0750 "$SAUV_DIR"
    if ! grep -q '^LABEL=SAUVEGARDES' /etc/fstab; then
        # nofail : la VM demarre meme sans le disque ; noexec,nosuid,nodev : rien ne s'execute depuis les sauvegardes
        printf 'LABEL=SAUVEGARDES\t/sauvegardes\text4\tdefaults,nodev,nosuid,noexec,nofail,x-systemd.device-timeout=10s\t0\t2\n' >> /etc/fstab
        systemctl daemon-reload
    fi
    mountpoint -q "$SAUV_DIR" || mount "$SAUV_DIR"
    chown root:admins "$SAUV_DIR"
    chmod 0750 "$SAUV_DIR"
    systemctl enable --now sauvegarde.timer >/dev/null 2>&1
    if [[ ! -e $SAUV_DIR/versions/derniere ]]; then
        systemctl start sauvegarde.service || attention "La premiere sauvegarde a echoue : journalctl -u sauvegarde.service"
    fi
fi

echo "==== 10. SSH ===="
cible=/etc/ssh/sshd_config.d/00-hardening.conf
if ! admin_avec_cle; then
    attention "Aucun admin n'a de cle SSH (config/keys/<login>.pub) : config SSH NON appliquee pour ne pas vous bloquer dehors"
else
    cp -a "$cible" "$cible.bak" 2>/dev/null || true
    install -m 0644 -o root -g root "$REPO/config/ssh/sshd_config.d/00-hardening.conf" "$cible"
    rm -f /etc/ssh/sshd_config.d/hardening.conf
    if sshd -t; then
        rm -f "$cible.bak"
        systemctl reload ssh                      # reload : les sessions ouvertes ne sont pas coupees
        echo "[OK] Config SSH validee par sshd -t et rechargee"
    else
        if [[ -f $cible.bak ]]; then mv "$cible.bak" "$cible"; else rm -f "$cible"; fi
        echo "[ERREUR] sshd -t refuse la config : ancienne config remise" >&2
        exit 1
    fi
fi

echo "==== 11. root verrouille, sudo reserve aux admins ===="
if ! admin_avec_mdp; then
    attention "Aucun admin n'a de mot de passe : root n'est PAS verrouille. Faire 'sudo passwd <admin>', tester ssh + sudo -v, puis relancer installer.sh"
else
    passwd -l root >/dev/null
    for u in $(getent group sudo | cut -d: -f4 | tr ',' ' '); do
        gpasswd -d "$u" sudo >/dev/null
        echo "[OK] $u retire du groupe sudo"
    done
    echo "[OK] root verrouille"
fi

echo
if (( NB_ATTENTION > 0 )); then
    echo "Voir les [ATTENTION] ci-dessus, puis relancer installer.sh."
else
    echo "Installation complete. Lancer : sudo ./verifier.sh"
fi
