#!/bin/bash
# preparer_disque.sh - formate UNE fois le second disque en ext4 (etiquette SAUVEGARDES)
# Usage : sudo ./preparer_disque.sh /dev/sdb
# Action manuelle : formater detruit les donnees, installer.sh ne le fait jamais.

set -eu
LABEL=SAUVEGARDES

[[ $EUID -eq 0 && $# -eq 1 ]] || { echo "Usage : sudo $0 /dev/sdX" >&2; exit 1; }
disque="$1"
[[ -b $disque ]] || { echo "[ERREUR] $disque n'est pas un disque" >&2; exit 1; }

# deja prepare : rien a faire
if [[ $(blkid -o value -s LABEL "$disque" 2>/dev/null || true) == "$LABEL" ]]; then
    echo "[INFO] $disque est deja prepare"
    exit 0
fi

# refuse un disque monte (le disque systeme est monte)
if lsblk -no MOUNTPOINTS "$disque" | grep -q '[^[:space:]]'; then
    echo "[ERREUR] $disque ou une de ses partitions est monte" >&2; exit 1
fi

# refuse un disque qui contient deja quelque chose
if [[ -n $(wipefs -n "$disque") ]]; then
    echo "[ERREUR] $disque n'est pas vierge" >&2; exit 1
fi

lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$disque"
read -r -p "$disque va etre formate. Retapez '$disque' pour confirmer : " reponse
[[ $reponse == "$disque" ]] || { echo "[ERREUR] Confirmation incorrecte, rien n'a ete fait" >&2; exit 1; }

mkfs.ext4 -q -L "$LABEL" "$disque"
echo "[OK] $disque formate (ext4, etiquette $LABEL)"
