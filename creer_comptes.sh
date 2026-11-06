#!/bin/bash
# creer_comptes.sh - groupes, comptes, cles SSH, dossiers /srv et ACL (C1, C2, C4)
# Usage : sudo ./creer_comptes.sh [comptes.csv]

set -eu

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV="${1:-$DIR/comptes.csv}"
KEYS="$DIR/config/keys"

[[ $EUID -eq 0 ]] || { echo "[ERREUR] Lancer avec sudo" >&2; exit 1; }
[[ -f $CSV ]] || { echo "[ERREUR] Fichier introuvable : $CSV" >&2; exit 1; }
[[ $(head -1 "$CSV" | tr -d '\r') == "login;nom;groupe_principal;groupes_secondaires" ]] \
    || { echo "[ERREUR] En-tete du CSV incorrect" >&2; exit 1; }

# lignes du CSV sans en-tete, sans lignes vides, sans \r (fichier cree sous Windows)
lire_csv() { tail -n +2 "$CSV" | tr -d '\r' | grep -v '^[[:space:]]*$' || true; }

creer_groupe() { getent group "$1" >/dev/null || groupadd "$1"; }

echo "[ETAPE 1] Groupes"
for g in admins support acces_ssh comptables rh direction stagiaire; do
    creer_groupe "$g"
done
while IFS=';' read -r login nom principal secondaires; do
    creer_groupe "$principal"
    for g in ${secondaires//,/ }; do creer_groupe "$g"; done
done < <(lire_csv)

echo "[ETAPE 2] Utilisateurs"
while IFS=';' read -r login nom principal secondaires; do
    if id "$login" >/dev/null 2>&1; then
        usermod -g "$principal" -c "$nom" "$login"
    else
        useradd -m -s /bin/bash -g "$principal" -c "$nom" "$login"   # sans mot de passe : compte verrouille
    fi
    if [[ -n $secondaires ]]; then
        usermod -aG "$secondaires" "$login"                          # -a : n'enleve pas les autres groupes
    fi
    chmod 700 "$(getent passwd "$login" | cut -d: -f6)"              # C4 : home prive
    echo "[OK] $login"
done < <(lire_csv)

echo "[ETAPE 3] Cles SSH (config/keys/<login>.pub)"
while IFS=';' read -r login nom principal secondaires; do
    [[ ",$secondaires," == *",acces_ssh,"* || $principal == acces_ssh ]] || continue
    cle="$KEYS/$login.pub"
    if [[ ! -f $cle ]] || ! ssh-keygen -l -f "$cle" >/dev/null 2>&1 || grep -q 'PRIVATE KEY' "$cle"; then
        echo "[ATTENTION] Pas de cle publique valide pour $login ($cle)"
        continue
    fi
    home="$(getent passwd "$login" | cut -d: -f6)"
    install -d -m 700 -o "$login" -g "$principal" "$home/.ssh"
    install -m 600 -o "$login" -g "$principal" "$cle" "$home/.ssh/authorized_keys"
    echo "[OK] Cle installee pour $login"
done < <(lire_csv)

echo "[ETAPE 4] Dossiers /srv, droits et ACL"
acl() {   # acl <dossier> <acl> <acl par defaut>
    setfacl -b "$1"
    setfacl -m "$2" "$1"
    setfacl -d -m "$3" "$1"
}

mkdir -p /srv/dossiers_clients /srv/rh /srv/commun/depot
chown root:root /srv
chmod 755 /srv
chown root:comptables /srv/dossiers_clients /srv/commun /srv/commun/depot
chown root:rh /srv/rh

# chmod AVANT setfacl (chmod changerait le masque de l'ACL)
chmod 2770 /srv/dossiers_clients /srv/rh /srv/commun   # setgid : les fichiers prennent le groupe du dossier
chmod 3770 /srv/commun/depot                           # + sticky bit : on ne supprime que ses fichiers

acl /srv/dossiers_clients "g:comptables:rwx,g:direction:r-x" "g:comptables:rwx,g:direction:r-x"
acl /srv/rh "g:rh:rwx,g:direction:r-x" "g:rh:rwx,g:direction:r-x"
acl /srv/commun "g:comptables:rwx,g:rh:rwx,g:direction:rwx,g:stagiaire:r-x" \
                "g:comptables:rwx,g:rh:rwx,g:direction:rwx,g:stagiaire:r-x"
# depot : le stagiaire peut deposer (-wx) sans lister, et n'a aucun droit sur les fichiers deposes
acl /srv/commun/depot "g:comptables:rwx,g:rh:rwx,g:direction:rwx,g:stagiaire:-wx" \
                      "g:comptables:rwx,g:rh:rwx,g:direction:rwx,g:stagiaire:---"

echo "[ETAPE 5] Recapitulatif"
while IFS=';' read -r login nom principal secondaires; do
    echo "  $login : $(id -nG "$login")"
done < <(lire_csv)
ls -ld /srv/dossiers_clients /srv/rh /srv/commun /srv/commun/depot
echo "[OK] creer_comptes.sh termine."
