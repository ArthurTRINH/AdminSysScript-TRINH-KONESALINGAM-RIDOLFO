#!/bin/bash

DEST_DIR="/var/backups/chiffres_co"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
ARCHIVE_NAME="backup_$DATE.tar.gz"

if [ "$EUID" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté avec les privilèges root." >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
echo "[+] Démarrage de la sauvegarde..."
tar -czf "$DEST_DIR/$ARCHIVE_NAME" /srv/dossiers_clients /srv/rh /srv/commun 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[+] Sauvegarde réussie : $DEST_DIR/$ARCHIVE_NAME"
else
    echo "[-] Erreur lors de la création de l'archive de sauvegarde." >&2
    exit 1
fi
