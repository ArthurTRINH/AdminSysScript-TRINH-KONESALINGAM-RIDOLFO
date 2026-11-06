#!/bin/bash
# sauvegarde.sh - sauvegarde /srv et /etc sur le second disque (B1, B2, B3)
# Lance chaque nuit par sauvegarde.timer.
# /sauvegardes/versions/AAAA-MM-JJ_HHMMSS : une version complete ; "derniere" pointe sur la plus recente.

set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin

DEST=/sauvegardes
VERSIONS=$DEST/versions
RETENTION=7   # nombre de versions gardees

log()  { logger -t sauvegarde "$*"; echo "[$(date '+%F %T')] $*"; }
fail() { logger -t sauvegarde -p user.err "ECHEC : $*"; echo "[ERREUR] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || { echo "[ERREUR] Lancer en root" >&2; exit 1; }
# sans ce test, on ecrirait sur le disque systeme si le second disque est absent
mountpoint -q "$DEST" || fail "$DEST n'est pas monte (second disque absent ?)"

# B3 : seuls root et le groupe admins accedent aux sauvegardes
chown root:admins "$DEST"
chmod 0750 "$DEST"
install -d -m 0750 -o root -g admins "$VERSIONS"

nom="$(date +%Y-%m-%d_%H%M%S)"
cible="$VERSIONS/$nom"
rm -rf "$VERSIONS"/*.incomplete              # version interrompue la fois d'avant

# --link-dest : un fichier identique a la derniere version devient un lien physique
options=(-aAXH --numeric-ids --delete --relative)
if [[ -d $VERSIONS/derniere ]]; then
    options+=("--link-dest=$(readlink -f "$VERSIONS/derniere")")
fi

log "debut : $nom"
code=0
rsync "${options[@]}" /srv /etc "$cible.incomplete/" || code=$?
if (( code == 24 )); then
    log "des fichiers ont disparu pendant la copie (code 24), sauvegarde gardee"
elif (( code != 0 )); then
    rm -rf "$cible.incomplete"
    fail "rsync a echoue (code $code)"
fi

# rsync perd l'entree "group::" de l'ACL des dossiers sticky (ex. depot) : on recopie l'ACL de la source
find "$cible.incomplete" -type d -perm -1000 | while IFS= read -r rep; do
    src="/${rep#"$cible.incomplete"/}"
    if [[ -d $src ]]; then
        getfacl -p "$src" | setfacl --set-file=- "$rep"
    fi
done

# la version n'a son nom definitif qu'une fois complete
mv "$cible.incomplete" "$cible"
chmod 0750 "$cible"
ln -sfn "$nom" "$VERSIONS/derniere"

# rotation : on garde les RETENTION versions les plus recentes
mapfile -t toutes < <(ls -1 "$VERSIONS" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$' | sort)
nb=${#toutes[@]}
if (( nb > RETENTION )); then
    for v in "${toutes[@]:0:nb-RETENTION}"; do
        rm -rf "${VERSIONS:?}/$v"
        log "rotation : version supprimee $v"
    done
fi

log "fin : succes ($cible)"
