#!/bin/bash

# ==================================================
# Projet : AdminSysScript
# Contexte : Cabinet comptable Chiffres & Co
# Script : creer_comptes.sh
# Description : Creation des groupes, utilisateurs,
#               repertoires et permissions ACL.
# ==================================================

set -euo pipefail

# Verifier les privileges administrateur
if [[ "$EUID" -ne 0 ]]; then
    echo "Erreur : executez ce script avec sudo."
    exit 1
fi

# Verifier la presence de setfacl
if ! command -v setfacl >/dev/null 2>&1; then
    echo "Erreur : le paquet acl doit etre installe."
    exit 1
fi

# Chemin du fichier CSV
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="$SCRIPT_DIR/comptes.csv"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "Erreur : comptes.csv introuvable."
    exit 1
fi

echo "======================================"
echo " Configuration Chiffres & Co"
echo "======================================"

# 1. Creation des groupes
GROUPS=("comptables" "rh" "direction" "stagiaire")

for group in "${GROUPS[@]}"; do
    if ! getent group "$group" >/dev/null; then
        groupadd "$group"
        echo "[OK] Groupe cree : $group"
    else
        echo "[INFO] Groupe deja existant : $group"
    fi
done

# 2. Creation des utilisateurs depuis le CSV
while IFS=';' read -r login nom groupe groupes_secondaires; do

    # Ignorer l'entete et les lignes vides
    [[ "$login" == "login" || -z "$login" ]] && continue

    if ! getent group "$groupe" >/dev/null; then
        echo "[ERREUR] Groupe inconnu : $groupe"
        exit 1
    fi

    if id "$login" >/dev/null 2>&1; then
        echo "[INFO] Utilisateur deja existant : $login"
        usermod -g "$groupe" "$login"
    else
        useradd -m -s /bin/bash -g "$groupe" "$login"
        echo "[OK] Utilisateur cree : $login"
    fi

    # Ajouter les groupes secondaires si renseignes
    if [[ -n "${groupes_secondaires:-}" ]]; then
        usermod -aG "$groupes_secondaires" "$login"
    fi

done < "$CSV_FILE"

# 3. Creation des repertoires
mkdir -p /srv/dossiers_clients
mkdir -p /srv/rh
mkdir -p /srv/commun/depot

# 4. Attribution des groupes proprietaires
chown root:comptables /srv/dossiers_clients
chown root:rh /srv/rh
chown root:comptables /srv/commun
chown root:comptables /srv/commun/depot

# 5. Permissions de base
chmod 2770 /srv/dossiers_clients
chmod 2770 /srv/rh
chmod 2770 /srv/commun
chmod 3770 /srv/commun/depot

# 6. Nettoyage des anciennes ACL gerees sur ces repertoires
setfacl -b -k /srv/dossiers_clients
setfacl -b -k /srv/rh
setfacl -b -k /srv/commun
setfacl -b -k /srv/commun/depot

# 7. DOSSIERS CLIENTS
# Comptables : lecture/ecriture
# Direction : lecture seule

setfacl -m g:comptables:rwx /srv/dossiers_clients
setfacl -m g:direction:rx /srv/dossiers_clients
setfacl -m o::--- /srv/dossiers_clients

setfacl -d -m g:comptables:rwx /srv/dossiers_clients
setfacl -d -m g:direction:rx /srv/dossiers_clients
setfacl -d -m o::--- /srv/dossiers_clients

# 8. RESSOURCES HUMAINES
# RH : lecture/ecriture
# Direction : lecture seule

setfacl -m g:rh:rwx /srv/rh
setfacl -m g:direction:rx /srv/rh
setfacl -m o::--- /srv/rh

setfacl -d -m g:rh:rwx /srv/rh
setfacl -d -m g:direction:rx /srv/rh
setfacl -d -m o::--- /srv/rh

# 9. DOSSIER COMMUN
# Comptables, RH et direction : lecture/ecriture
# Stagiaires : lecture seule

setfacl -m g:comptables:rwx /srv/commun
setfacl -m g:rh:rwx /srv/commun
setfacl -m g:direction:rwx /srv/commun
setfacl -m g:stagiaire:rx /srv/commun
setfacl -m o::--- /srv/commun

setfacl -d -m g:comptables:rwx /srv/commun
setfacl -d -m g:rh:rwx /srv/commun
setfacl -d -m g:direction:rwx /srv/commun
setfacl -d -m g:stagiaire:rx /srv/commun
setfacl -d -m o::--- /srv/commun

# 10. DOSSIER DEPOT
# Comptables, RH et direction : lecture/ecriture
# Stagiaires : depot sans lecture de la liste
# Sticky bit : protection des fichiers des autres utilisateurs

setfacl -m g:comptables:rwx /srv/commun/depot
setfacl -m g:rh:rwx /srv/commun/depot
setfacl -m g:direction:rwx /srv/commun/depot
setfacl -m g:stagiaire:-wx /srv/commun/depot
setfacl -m o::--- /srv/commun/depot

# ACL par defaut pour les nouveaux fichiers et dossiers
setfacl -d -m g:comptables:rwX /srv/commun/depot
setfacl -d -m g:rh:rwX /srv/commun/depot
setfacl -d -m g:direction:rwX /srv/commun/depot
setfacl -d -m g:stagiaire:--- /srv/commun/depot
setfacl -d -m o::--- /srv/commun/depot

echo ""
echo "======================================"
echo " Configuration terminee avec succes"
echo "======================================"

echo "Groupes :"
getent group comptables rh direction stagiaire

echo ""
echo "Utilisateurs :"
for user in darksasuke garen hardstuckiron freetoplay \
            imissher roadtoplatine bigbot gregoriz; do
    id "$user"
done

echo ""
echo "Permissions :"
getfacl /srv/dossiers_clients
getfacl /srv/rh
getfacl /srv/commun
getfacl /srv/commun/depot
