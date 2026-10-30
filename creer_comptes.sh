#!/bin/bash

# ==================================================
# Projet : AdminSysScript
# Contexte : Cabinet comptable Chiffres & Co
# Script : creer_comptes.sh
# Parties  : 3 et 4
# ==================================================

set -Eeuo pipefail

# Gestion des erreurs
trap 'echo "[ERREUR] Probleme a la ligne ${LINENO}." >&2' ERR

# 1. Verification des privileges administrateur
if [[ "$EUID" -ne 0 ]]; then
    echo "[ERREUR] Ce script doit etre execute avec sudo."
    exit 1
fi

# 2. Verification des commandes necessaires
for cmd in groupadd useradd usermod id getent mkdir chown; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERREUR] Commande manquante : $cmd"
        exit 1
    fi
done

# 3. Localisation du fichier CSV
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="$SCRIPT_DIR/comptes.csv"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "[ERREUR] comptes.csv introuvable."
    exit 1
fi

# 4. Verification de la structure CSV
awk -F';' '
NR == 1 {
    if ($1 != "login" || $2 != "nom" ||
        $3 != "groupe_principal" ||
        $4 != "groupes_secondaires") {
        print "[ERREUR] En-tete CSV incorrect."
        erreur = 1
    }
    next
}
NF == 0 { next }
NF != 4 {
    print "[ERREUR] Nombre de colonnes incorrect ligne " NR
    erreur = 1
}
END {
    if (NR == 0) {
        print "[ERREUR] Fichier CSV vide."
        erreur = 1
    }
    exit erreur
}' "$CSV_FILE"

echo "=========================================="
echo " CHIFFRES & CO - CREATION DES COMPTES"
echo "=========================================="

# ==================================================
# PARTIE 3 : GROUPES ET UTILISATEURS
# ==================================================

echo ""
echo "[ETAPE 1] Creation des groupes"

GROUPS_METIER=("comptables" "rh" "direction" "stagiaire")

for groupe in "${GROUPS_METIER[@]}"; do

    if getent group "$groupe" >/dev/null; then
        echo "[INFO] Groupe deja existant : $groupe"
    else
        groupadd "$groupe"
        echo "[OK] Groupe cree : $groupe"
    fi

done

echo ""
echo "[ETAPE 2] Creation des utilisateurs"

while IFS=';' read -r login nom groupe groupes_secondaires; do

    # Ignorer l'en-tete et les lignes vides
    [[ "$login" == "login" || -z "$login" ]] && continue

    # Verifier le groupe principal
    if ! getent group "$groupe" >/dev/null; then
        echo "[ERREUR] Groupe principal inconnu : $groupe"
        exit 1
    fi

    # Verifier les groupes secondaires
    if [[ -n "$groupes_secondaires" ]]; then
        IFS=',' read -ra groupes_array <<< "$groupes_secondaires"

        for groupe_sec in "${groupes_array[@]}"; do
            if ! getent group "$groupe_sec" >/dev/null; then
                echo "[ERREUR] Groupe secondaire inconnu : $groupe_sec"
                exit 1
            fi
        done
    fi

    # Creer ou mettre a jour le compte
    if id "$login" >/dev/null 2>&1; then

        echo "[INFO] Utilisateur deja existant : $login"

        usermod -g "$groupe" -c "$nom" "$login"

        echo "[OK] Groupe principal mis a jour : $login"

    else

        if [[ -n "$groupes_secondaires" ]]; then
            useradd -m -s /bin/bash -g "$groupe" \
                -c "$nom" -G "$groupes_secondaires" "$login"
        else
            useradd -m -s /bin/bash -g "$groupe" \
                -c "$nom" "$login"
        fi

        echo "[OK] Utilisateur cree : $login"

    fi

    # Ajouter les groupes secondaires
    if [[ -n "$groupes_secondaires" ]]; then
        usermod -aG "$groupes_secondaires" "$login"
        echo "[OK] Groupes secondaires attribues : $login"
    fi

done < <(tail -n +2 "$CSV_FILE")

# ==================================================
# PARTIE 4 : CREATION DES REPERTOIRES
# ==================================================

echo ""
echo "[ETAPE 3] Creation des repertoires"

mkdir -p /srv/dossiers_clients
mkdir -p /srv/rh
mkdir -p /srv/commun
mkdir -p /srv/commun/depot

echo "[OK] Repertoires crees."

# Attribution des proprietaires et groupes
echo ""
echo "[ETAPE 4] Attribution des proprietaires"

chown root:comptables /srv/dossiers_clients
chown root:rh /srv/rh
chown root:comptables /srv/commun
chown root:comptables /srv/commun/depot

echo "[OK] Proprietaires et groupes attribues."

# ==================================================
# VERIFICATION FINALE
# ==================================================

echo ""
echo "=========================================="
echo " VERIFICATION DES UTILISATEURS"
echo "=========================================="

for login in darksasuke garen hardstuckiron freetoplay \
             imissher roadtoplatine bigbot gregoriz; do

    if id "$login" >/dev/null 2>&1; then
        echo "[OK] $login : $(id -gn "$login")"
    else
        echo "[ERREUR] Utilisateur absent : $login"
    fi

done

echo ""
echo "=========================================="
echo " VERIFICATION DES REPERTOIRES"
echo "=========================================="

ls -ld /srv/dossiers_clients
ls -ld /srv/rh
ls -ld /srv/commun
ls -ld /srv/commun/depot

echo ""
echo "=========================================="
echo " CONFIGURATION TERMINEE"
echo "=========================================="
