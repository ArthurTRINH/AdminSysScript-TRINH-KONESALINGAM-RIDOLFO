#!/bin/bash
# verifier.sh - teste chaque exigence et affiche [OK] ou [KO]
# Usage : sudo ./verifier.sh        (depuis le dossier du depot)
# Code de sortie : 0 si tout est OK, 1 sinon, 2 si mal lance
# Pas de "set -e" : on lance volontairement des commandes qui doivent echouer.

set -u
export LC_ALL=C

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd /
CSV="$REPO/comptes.csv"
SAUV=/sauvegardes
ANALYSE=/usr/local/sbin/analyse_logs.sh
SUID_LISTE="$REPO/config/suid_attendus.txt"
P=".verif_$$"            # debut du nom des fichiers de test (supprimes a la fin)
DEBUT="$(date +%s)"
OK=0
TOTAL=0

ok() { echo "[OK] $1 $2"; OK=$((OK + 1)); TOTAL=$((TOTAL + 1)); }
ko() { echo "[KO] $1 $2"; TOTAL=$((TOTAL + 1)); }

nettoyer() { rm -f /srv/dossiers_clients/"$P"* /srv/rh/"$P"* /srv/commun/"$P"* /srv/commun/depot/"$P"*; }
trap nettoyer EXIT

# ajout a un fichier existant sans O_CREAT (voir tests_acl.sh)
AJOUT='printf x | dd of="$1" conv=nocreat,notrunc oflag=append status=none'

# permis <id> <texte> <user> <commande...> : la commande doit reussir
permis() {
    local id="$1" texte="$2" u="$3"; shift 3
    if runuser -u "$u" -- "$@" >/dev/null 2>&1; then ok "$id" "$texte"; else ko "$id" "$texte (refuse)"; fi
}
# interdit <id> <texte> <user> <commande...> : la commande doit echouer
interdit() {
    local id="$1" texte="$2" u="$3"; shift 3
    if runuser -u "$u" -- "$@" >/dev/null 2>&1; then ko "$id" "$texte (permis !)"; else ok "$id" "$texte"; fi
}

lignes_csv() { tail -n +2 "$CSV" | tr -d '\r' | grep -v '^[[:space:]]*$'; }
membres() { lignes_csv | awk -F';' -v g="$1" '$3 == g { print $1 }'; }   # groupe principal = $1
sshd_opt() { sshd -T 2>/dev/null | awk -v k="$1" '$1 == k { $1 = ""; sub(/^ /, ""); print; exit }'; }
secondes() { case "$1" in *m) echo $(( ${1%m} * 60 )) ;; *h) echo $(( ${1%h} * 3600 )) ;; *s) echo "${1%s}" ;; *) echo "$1" ;; esac; }

# connexion SSH locale sans cle : affiche la reponse du serveur
essai_ssh() {
    timeout 15 ssh -n -o BatchMode=yes -o PubkeyAuthentication=no \
        -o PreferredAuthentications=password,keyboard-interactive \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR "$1@127.0.0.1" true 2>&1
}

prerequis() {
    [[ $EUID -eq 0 ]] || { echo "[ERREUR] Lancer avec sudo" >&2; exit 2; }
    [[ -f $CSV ]] || { echo "[ERREUR] $CSV introuvable" >&2; exit 2; }
    ADMIN="$(membres admins | head -1)"
    mapfile -t COMPTA < <(membres comptables)
    mapfile -t RH < <(membres rh)
    mapfile -t DIR < <(membres direction)
    mapfile -t STAG < <(membres stagiaire)
    if [[ -z $ADMIN ]] || (( ${#COMPTA[@]} < 2 || ${#RH[@]} < 2 || ${#DIR[@]} < 2 || ${#STAG[@]} < 2 )); then
        echo "[ERREUR] comptes.csv : il faut 1 admin et au moins 2 comptes par groupe metier" >&2; exit 2
    fi
}

# ================= C : comptes et droits =================

test_C1() {
    if [[ $(head -1 "$CSV" | tr -d '\r') == "login;nom;groupe_principal;groupes_secondaires" ]]; then
        ok C1 "comptes.csv : en-tete conforme"
    else
        ko C1 "comptes.csv : en-tete incorrect"
    fi
    local login principal secondaires g manque attendus reels intrus
    while IFS=';' read -r login _ principal secondaires; do
        if ! id "$login" >/dev/null 2>&1; then ko C1 "compte $login absent"; continue; fi
        manque=""
        [[ $(id -gn "$login") == "$principal" ]] || manque="groupe principal"
        for g in ${secondaires//,/ }; do
            id -nG "$login" | tr ' ' '\n' | grep -qx "$g" || manque="$manque $g"
        done
        if [[ -z $manque ]]; then ok C1 "compte $login conforme au CSV"; else ko C1 "compte $login : manque $manque"; fi
    done < <(lignes_csv)

    # acces_ssh ne doit contenir que les comptes prevus
    attendus="$(lignes_csv | awk -F';' '("," $4 ",") ~ /,acces_ssh,/ || $3 == "acces_ssh" { print $1 }' | sort)"
    reels="$(getent group acces_ssh | cut -d: -f4 | tr ',' '\n' | sort)"
    intrus="$(comm -13 <(echo "$attendus") <(echo "$reels") | grep -v '^$' || true)"
    if getent group acces_ssh >/dev/null && [[ -z $intrus ]]; then
        ok C1 "acces_ssh ne contient que les comptes prevus"
    else
        ko C1 "acces_ssh absent ou membres non prevus : $intrus"
    fi
}

test_C2() {
    local d f s1="${STAG[0]}" s2="${STAG[1]}"
    for d in /srv/dossiers_clients /srv/rh /srv/commun /srv/commun/depot; do
        if getfacl -pc "$d" 2>/dev/null | grep -q '^default:group:'; then ok C2 "$d : ACL par defaut presentes"
        else ko C2 "$d : absent ou sans ACL par defaut"; fi
    done
    if [[ $(stat -c %a /srv/commun/depot) == 3770 ]]; then ok C2 "depot en 3770 (sticky bit + setgid)"
    else ko C2 "depot : droits $(stat -c %a /srv/commun/depot) au lieu de 3770"; fi

    f="/srv/dossiers_clients/${P}_c"
    permis   C2 "comptable ${COMPTA[0]} cree un fichier dans dossiers_clients" "${COMPTA[0]}" touch "$f"
    permis   C2 "comptable ${COMPTA[1]} modifie ce fichier" "${COMPTA[1]}" bash -c "$AJOUT" _ "$f"
    permis   C2 "direction ${DIR[0]} lit dossiers_clients" "${DIR[0]}" cat "$f"
    interdit C2 "direction ${DIR[0]} ne modifie pas dossiers_clients" "${DIR[0]}" bash -c "$AJOUT" _ "$f"
    interdit C2 "rh ${RH[0]} ne liste pas dossiers_clients" "${RH[0]}" ls /srv/dossiers_clients
    interdit C2 "stagiaire $s1 ne lit pas dossiers_clients" "$s1" cat "$f"

    f="/srv/rh/${P}_rh"
    permis   C2 "rh ${RH[0]} cree un fichier dans /srv/rh" "${RH[0]}" touch "$f"
    permis   C2 "rh ${RH[1]} modifie ce fichier" "${RH[1]}" bash -c "$AJOUT" _ "$f"
    permis   C2 "direction ${DIR[1]} lit /srv/rh" "${DIR[1]}" cat "$f"
    interdit C2 "direction ${DIR[1]} ne cree pas de fichier dans /srv/rh" "${DIR[1]}" touch "/srv/rh/${P}_x"
    interdit C2 "comptable ${COMPTA[0]} ne lit pas /srv/rh" "${COMPTA[0]}" cat "$f"
    interdit C2 "stagiaire $s1 ne liste pas /srv/rh" "$s1" ls /srv/rh

    f="/srv/commun/${P}_m"
    permis   C2 "rh ${RH[0]} cree un fichier dans commun" "${RH[0]}" touch "$f"
    permis   C2 "direction ${DIR[0]} modifie un fichier de commun" "${DIR[0]}" bash -c "$AJOUT" _ "$f"
    permis   C2 "comptable ${COMPTA[0]} modifie un fichier de commun" "${COMPTA[0]}" bash -c "$AJOUT" _ "$f"
    permis   C2 "stagiaire $s1 lit commun" "$s1" cat "$f"
    interdit C2 "stagiaire $s1 ne modifie pas commun" "$s1" bash -c "$AJOUT" _ "$f"
    interdit C2 "stagiaire $s1 ne cree pas de fichier dans commun" "$s1" touch "/srv/commun/${P}_s"

    f="/srv/commun/depot/${P}_stag"
    permis   C2 "stagiaire $s1 depose un fichier dans depot" "$s1" touch "$f"
    interdit C2 "stagiaire $s1 ne liste pas depot" "$s1" ls /srv/commun/depot
    interdit C2 "stagiaire $s2 ne lit pas le fichier de $s1" "$s2" cat "$f"
    interdit C2 "stagiaire $s2 ne modifie pas le fichier de $s1" "$s2" bash -c "$AJOUT" _ "$f"
    interdit C2 "stagiaire $s2 ne supprime pas le fichier de $s1" "$s2" rm -f "$f"
    permis   C2 "comptable ${COMPTA[0]} lit le fichier depose par $s1" "${COMPTA[0]}" cat "$f"
    permis   C2 "rh ${RH[0]} modifie le fichier depose par $s1" "${RH[0]}" bash -c "$AJOUT" _ "$f"
}

test_C3() {
    local a u c sortie interdite="" fautifs="" autorises
    for a in $(membres admins); do
        if sudo -l -U "$a" 2>/dev/null | grep -q '(ALL : ALL) ALL'; then ok C3 "l'admin $a a sudo"
        else ko C3 "l'admin $a n'a pas sudo"; fi
    done
    if sudo -l -U support "$ANALYSE" >/dev/null 2>&1; then ok C3 "support peut lancer analyse_logs.sh en root"
    else ko C3 "support ne peut pas lancer $ANALYSE"; fi
    for c in /bin/bash /usr/bin/journalctl /usr/bin/less /usr/bin/vi /usr/local/sbin/sauvegarde.sh; do
        sudo -l -U support "$c" >/dev/null 2>&1 && interdite="$interdite $c"
    done
    if [[ -z $interdite ]]; then ok C3 "support ne peut rien lancer d'autre en sudo"
    else ko C3 "support peut aussi lancer :$interdite"; fi

    # aucun autre compte humain (UID >= 1000) n'a sudo
    autorises=" $(membres admins | tr '\n' ' ') support "
    while IFS=: read -r u _ uid _; do
        (( uid >= 1000 && uid < 60000 )) || continue
        [[ $autorises == *" $u "* ]] && continue
        sortie="$(sudo -l -U "$u" 2>&1)"
        grep -q 'not allowed to run sudo' <<< "$sortie" || fautifs="$fautifs $u"
    done < /etc/passwd
    if [[ -z $fautifs ]]; then ok C3 "aucun autre compte n'a sudo"
    else ko C3 "comptes avec sudo sans etre admins/support :$fautifs"; fi
}

test_C4() {
    local d lisibles=""
    if [[ $(passwd -S root | awk '{print $2}') == L ]]; then ok C4 "root est verrouille"
    else ko C4 "root n'est pas verrouille"; fi
    for d in /home/*/; do
        [[ -d $d ]] || continue
        (( 8#$(stat -c %a "$d") & 8#077 )) && lisibles="$lisibles $d"
    done
    if [[ -z $lisibles ]]; then ok C4 "aucun repertoire personnel accessible aux autres"
    else ko C4 "repertoires personnels accessibles :$lisibles"; fi
    interdit C4 "${COMPTA[1]} ne liste pas le home de ${COMPTA[0]}" "${COMPTA[1]}" \
        ls "$(getent passwd "${COMPTA[0]}" | cut -d: -f6)"
}

# ================= S : SSH =================

test_S1() {
    if [[ $(sshd_opt passwordauthentication) == no && $(sshd_opt kbdinteractiveauthentication) == no \
          && $(sshd_opt pubkeyauthentication) == yes ]]; then
        ok S1 "sshd : cle publique seule (mot de passe desactive)"
    else
        ko S1 "sshd : mot de passe encore possible"
    fi
    if essai_ssh "$ADMIN" | grep -q 'Permission denied (publickey)'; then
        ok S1 "connexion de $ADMIN sans cle refusee (publickey seulement)"
    else
        ko S1 "connexion de $ADMIN sans cle : reponse inattendue"
    fi
}

test_S2() {
    if [[ $(sshd_opt permitrootlogin) == no ]]; then ok S2 "PermitRootLogin no"
    else ko S2 "PermitRootLogin vaut '$(sshd_opt permitrootlogin)'"; fi
}

test_S3() {
    if [[ $(sshd_opt allowgroups) == acces_ssh ]]; then ok S3 "AllowGroups acces_ssh"
    else ko S3 "AllowGroups vaut '$(sshd_opt allowgroups)'"; fi
    essai_ssh "${COMPTA[0]}" >/dev/null
    sleep 1
    if journalctl -u ssh.service --since "@$DEBUT" --no-pager -q 2>/dev/null \
         | grep -q "User ${COMPTA[0]} from .* not allowed because"; then
        ok S3 "connexion reelle de ${COMPTA[0]} (comptables) refusee par AllowGroups"
    else
        ko S3 "aucun refus AllowGroups dans le journal pour ${COMPTA[0]}"
    fi
}

test_S4() {
    local essais ct
    essais="$(sshd_opt maxauthtries)"
    if [[ $essais =~ ^[0-9]+$ ]] && (( essais <= 4 )); then ok S4 "MaxAuthTries $essais (<= 4)"
    else ko S4 "MaxAuthTries vaut '$essais' (attendu <= 4)"; fi
    ct="$(sshd_opt channeltimeout | tr ' ' '\n' | awk -F= '$1 == "session" { print $2 }')"
    if [[ -n $ct ]] && (( $(secondes "$ct") <= 900 )); then ok S4 "session inactive fermee apres $ct"
    else ko S4 "pas de ChannelTimeout session <= 15m"; fi
}

test_S5() {
    if grep -qsi '^[[:space:]]*PasswordAuthentication[[:space:]]\+no' /etc/ssh/sshd_config.d/*.conf; then
        ok S5 "config dans /etc/ssh/sshd_config.d/"
    else
        ko S5 "aucune config du projet dans /etc/ssh/sshd_config.d/"
    fi
    if sshd -t 2>/dev/null; then ok S5 "sshd -t valide la configuration"
    else ko S5 "sshd -t : $(sshd -t 2>&1 | head -1)"; fi
}

# ================= J : journaux et defense =================

test_J1() {
    if systemctl is-active -q fail2ban && systemctl is-enabled -q fail2ban; then ok J1 "fail2ban actif et lance au demarrage"
    else ko J1 "fail2ban inactif ou non active au demarrage"; fi
    if fail2ban-client status sshd >/dev/null 2>&1; then
        ok J1 "jail sshd active (maxretry $(fail2ban-client get sshd maxretry), bantime $(fail2ban-client get sshd bantime)s)"
        if fail2ban-client get sshd actions | grep -q nftables; then ok J1 "bannissement via nftables"
        else ko J1 "bannissement : pas nftables"; fi
    else
        ko J1 "jail sshd inactive"
    fi
}

test_J2() {
    local regles autres
    regles="$(nft list chain inet filter input 2>/dev/null)"
    if systemctl is-enabled -q nftables; then ok J2 "nftables charge au demarrage"
    else ko J2 "nftables non active au demarrage"; fi
    if grep -q 'hook input.*policy drop' <<< "$regles"; then ok J2 "politique par defaut en entree : drop"
    else ko J2 "politique par defaut en entree differente de drop"; fi
    if grep -q 'ct state established,related accept' <<< "$regles" && grep -q 'tcp dport 22 .*accept' <<< "$regles"; then
        ok J2 "entree autorisee : connexions etablies et SSH (22)"
    else
        ko J2 "regles 'established' ou 'tcp dport 22 accept' absentes"
    fi
    autres="$(grep dport <<< "$regles" | grep accept | grep -v 'dport 22 ' || true)"
    if [[ -z $autres ]]; then ok J2 "aucun autre port ouvert en entree"
    else ko J2 "autres ports ouverts : $autres"; fi
    if ! grep -q '^[[:space:]]*flush ruleset' /etc/nftables.conf; then ok J2 "pas de 'flush ruleset' (bans fail2ban preserves)"
    else ko J2 "'flush ruleset' dans /etc/nftables.conf efface les bans fail2ban"; fi
}

test_J3() {
    local storage
    storage="$(systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^Storage=' | tail -1 | cut -d= -f2)"
    if [[ $storage == persistent ]]; then ok J3 "journald : Storage=persistent"
    else ko J3 "journald : Storage='${storage:-defaut}' (attendu persistent)"; fi
    if compgen -G "/var/log/journal/*/system*.journal" >/dev/null; then ok J3 "journal ecrit dans /var/log/journal"
    else ko J3 "aucun journal dans /var/log/journal"; fi
}

test_J4() {
    local c
    if [[ -x $ANALYSE && $(stat -c '%U %a' "$ANALYSE") == "root 755" ]]; then ok J4 "analyse_logs.sh installe (root, 755)"
    else ko J4 "$ANALYSE absent ou droits incorrects"; fi
    "$ANALYSE" -s abc >/dev/null 2>&1; c=$?
    if (( c == 2 )); then ok J4 "argument invalide refuse (code 2)"; else ko J4 "argument invalide : code $c (attendu 2)"; fi
    "$ANALYSE" -s 999999 >/dev/null 2>&1; c=$?
    if (( c == 0 )); then ok J4 "seuil non atteint : code 0"; else ko J4 "seuil non atteint : code $c (attendu 0)"; fi
    # les tests S1 et S3 ont produit des echecs de connexion : avec un seuil de 0, alerte attendue
    "$ANALYSE" -s 0 -H 1 >/dev/null 2>&1; c=$?
    if (( c == 1 )); then ok J4 "seuil depasse : code 1"; else ko J4 "seuil depasse : code $c (attendu 1)"; fi
}

# ================= B : sauvegardes =================

test_B1() {
    local v derniere ret
    if mountpoint -q "$SAUV" && [[ $(stat -c %d "$SAUV") != $(stat -c %d /) ]]; then
        ok B1 "$SAUV est un disque separe ($(findmnt -no SOURCE "$SAUV"))"
    else
        ko B1 "$SAUV n'est pas un point de montage distinct de /"; return
    fi
    mapfile -t v < <(ls -d "$SAUV"/versions/20*_* 2>/dev/null | grep -v incomplete | sort)
    if (( ${#v[@]} == 0 )); then ko B1 "aucune version de sauvegarde"; return; fi
    derniere="${v[-1]}"
    if [[ -d $derniere/srv/commun/depot && -f $derniere/etc/passwd ]]; then ok B1 "${#v[@]} version(s), la derniere contient /srv et /etc"
    else ko B1 "la derniere version ne contient pas /srv et /etc"; fi
    if diff <(getfacl -pc /srv/commun/depot 2>/dev/null) <(getfacl -pc "$derniere/srv/commun/depot" 2>/dev/null) >/dev/null \
       && [[ $(stat -c '%a %U %G' /srv/commun/depot) == $(stat -c '%a %U %G' "$derniere/srv/commun/depot") ]]; then
        ok B1 "droits et ACL conserves dans la sauvegarde"
    else
        ko B1 "droits ou ACL de depot differents dans la sauvegarde"
    fi
    if (( ${#v[@]} >= 2 )); then
        if [[ $(stat -c %i "${v[-1]}/etc/debian_version") == $(stat -c %i "${v[-2]}/etc/debian_version") ]]; then
            ok B1 "incrementale : fichier inchange partage entre deux versions (meme inode)"
        else
            ko B1 "fichiers inchanges recopies (--link-dest ?)"
        fi
    else
        ko B1 "une seule version : relancer sauvegarde.sh pour prouver l'incremental"
    fi
    ret="$(grep -oE '^RETENTION=[0-9]+' /usr/local/sbin/sauvegarde.sh 2>/dev/null | cut -d= -f2)"
    if [[ -n $ret ]] && (( ret >= 7 && ${#v[@]} <= ret )); then ok B1 "rotation : $ret versions au maximum (${#v[@]} presentes)"
    else ko B1 "rotation : RETENTION='$ret', ${#v[@]} versions presentes"; fi
}

test_B2() {
    if systemctl is-enabled -q sauvegarde.timer && systemctl is-active -q sauvegarde.timer; then ok B2 "sauvegarde.timer actif"
    else ko B2 "sauvegarde.timer inactif ou non active"; fi
    if journalctl -t sauvegarde --no-pager -q 2>/dev/null | grep -q 'fin : succes'; then ok B2 "executions journalisees (journalctl -t sauvegarde)"
    else ko B2 "aucune sauvegarde reussie dans le journal"; fi
}

test_B3() {
    if [[ $(stat -c '%U %G %a' "$SAUV") == "root admins 750" ]]; then ok B3 "$SAUV : root:admins 750"
    else ko B3 "$SAUV : $(stat -c '%U:%G %a' "$SAUV") (attendu root:admins 750)"; fi
    permis   B3 "l'admin $ADMIN liste les sauvegardes" "$ADMIN" ls "$SAUV"
    interdit B3 "la direction (${DIR[0]}) ne liste pas les sauvegardes" "${DIR[0]}" ls "$SAUV"
    interdit B3 "support ne liste pas les sauvegardes" support ls "$SAUV"
}

test_B4() {
    local doc="$REPO/docs/restauration.md"
    if [[ -s $doc ]] && grep -q 'rsync' "$doc" && grep -qi 'test' "$doc"; then ok B4 "docs/restauration.md present"
    else ko B4 "docs/restauration.md vide ou incomplet"; fi
}

# ================= D : systeme =================

test_D1() {
    if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q 'install ok installed' \
       && apt-config dump | grep -q 'APT::Periodic::Unattended-Upgrade "1"' \
       && systemctl is-enabled -q apt-daily-upgrade.timer; then
        ok D1 "mises a jour de securite automatiques actives"
    else
        ko D1 "unattended-upgrades absent ou timer inactif"
    fi
}

test_D2() {
    local autres
    # ecoutes hors boucle locale, sauf sshd (22) et le client DHCP (68)
    autres="$(ss -Htulpn 2>/dev/null | awk '{ print $1, $5, $7 }' \
        | grep -vE ' (127\.[0-9.]+|\[::1\]|::1):[0-9]+ ' \
        | grep -vE ':22 .*"sshd"' \
        | grep -vE ':68 ' || true)"
    if [[ -z $autres ]]; then ok D2 "seul SSH ecoute sur le reseau"
    else ko D2 "autres services en ecoute : $(tr '\n' ';' <<< "$autres")"; fi
}

test_D3() {
    local m s ww="" wd="" inattendus="" attendus
    # systemes de fichiers reels seulement (pas /proc, /sys...), sans /tmp, /var/tmp, /dev/shm
    for m in $(findmnt -rno TARGET -t ext2,ext3,ext4,xfs,btrfs,vfat); do
        ww="$ww$(find "$m" -xdev \( -path /tmp -o -path /var/tmp -o -path /dev/shm \) -prune -o -type f -perm -0002 -print 2>/dev/null)"
        wd="$wd$(find "$m" -xdev \( -path /tmp -o -path /var/tmp -o -path /dev/shm \) -prune -o -type d -perm -0002 ! -perm -1000 -print 2>/dev/null)"
    done
    if [[ -z $ww ]]; then ok D3 "aucun fichier modifiable par tous"
    else ko D3 "fichiers modifiables par tous : $(head -3 <<< "$ww" | tr '\n' ' ')"; fi
    if [[ -z $wd ]]; then ok D3 "aucun repertoire modifiable par tous sans sticky bit"
    else ko D3 "repertoires modifiables par tous sans sticky bit : $(head -3 <<< "$wd" | tr '\n' ' ')"; fi

    if [[ ! -f $SUID_LISTE ]]; then ko D3 "$SUID_LISTE absent"; return; fi
    attendus="$(grep -v '^#' "$SUID_LISTE" | awk '{print $1}')"
    for m in $(findmnt -rno TARGET -t ext2,ext3,ext4,xfs,btrfs,vfat); do
        while IFS= read -r s; do
            grep -qxF -- "$s" <<< "$attendus" || inattendus="$inattendus $s"
        done < <(find "$m" -xdev -type f \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null)
    done
    if [[ -z $inattendus ]]; then ok D3 "tous les SUID/SGID sont dans config/suid_attendus.txt"
    else ko D3 "SUID/SGID non listes :$inattendus"; fi
}

# ================= Programme principal =================
prerequis
echo "=== verifier.sh - $(hostname) - $(date '+%F %T') ==="
test_C1; test_C2; test_C3; test_C4
test_S1; test_S2; test_S3; test_S4; test_S5
test_J1; test_J2; test_J3; test_J4
test_B1; test_B2; test_B3; test_B4
test_D1; test_D2; test_D3
echo "--- $OK / $TOTAL tests reussis"
if (( OK == TOTAL )); then exit 0; fi
exit 1
