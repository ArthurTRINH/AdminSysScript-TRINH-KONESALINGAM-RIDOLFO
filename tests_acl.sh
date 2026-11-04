#!/usr/bin/env bash
# ==================================================
# Projet  : AdminSysScript - Cabinet comptable Chiffres & Co
# Script  : tests_acl.sh
# Partie  : 6 - Verification automatique des permissions (exigence C2)
# --------------------------------------------------
# A lancer en root sur le serveur Debian, apres creer_comptes.sh.
# Verifie les acces AUTORISES et les acces INTERDITS avec de vrais
# fichiers crees par les vrais utilisateurs.
# Ne modifie rien d'autre que des fichiers temporaires (supprimes a la fin).
# Pas de "set -e" : certaines commandes DOIVENT echouer.
# ==================================================
# shellcheck disable=SC2016
set -uo pipefail

readonly CLIENTS=/srv/dossiers_clients
readonly RH=/srv/rh
readonly COMMUN=/srv/commun
readonly DEPOT=/srv/commun/depot
readonly COMPTABLES=(darksasuke garen)
readonly RHS=(hardstuckiron freetoplay)
readonly DIRECTIONS=(imissher roadtoplatine)
readonly STAGIAIRES=(bigbot gregoriz)
readonly PREFIXE=".verif_$$"

OK=0
TOTAL=0

ok() { echo "[OK] $1 $2"; OK=$((OK + 1)); TOTAL=$((TOTAL + 1)); }
ko() { echo "[KO] $1 $2"; TOTAL=$((TOTAL + 1)); }

# Suppression des fichiers de test, meme en cas d'arret du script
# shellcheck disable=SC2317,SC2329
nettoyer() {
    rm -f "$CLIENTS/$PREFIXE"* "$RH/$PREFIXE"* "$COMMUN/$PREFIXE"* "$DEPOT/$PREFIXE"*
}
trap nettoyer EXIT

# reussit <id> <description> <utilisateur> <commande...> : la commande doit marcher
reussit() {
    local id="$1" desc="$2" user="$3"
    shift 3
    if runuser -u "$user" -- "$@" >/dev/null 2>&1; then
        ok "$id" "$desc"
    else
        ko "$id" "$desc (refuse alors que ca devrait marcher)"
    fi
}

# refuse <id> <description> <utilisateur> <commande...> : la commande doit echouer
refuse() {
    local id="$1" desc="$2" user="$3"
    shift 3
    if runuser -u "$user" -- "$@" >/dev/null 2>&1; then
        ko "$id" "$desc (autorise alors que ca devrait etre interdit)"
    else
        ok "$id" "$desc"
    fi
}

# Evite les faux [OK] : un acces "refuse" parce qu'un compte ou un dossier n'existe pas
test_prerequis() {
    local u d
    if [[ $EUID -ne 0 ]]; then
        echo "[ERREUR] Ce script doit etre lance en root." >&2
        exit 2
    fi
    for u in "${COMPTABLES[@]}" "${RHS[@]}" "${DIRECTIONS[@]}" "${STAGIAIRES[@]}"; do
        id "$u" >/dev/null 2>&1 || { echo "[ERREUR] Utilisateur $u introuvable (lancer creer_comptes.sh)" >&2; exit 2; }
    done
    for d in "$CLIENTS" "$RH" "$COMMUN" "$DEPOT"; do
        [[ -d $d ]] || { echo "[ERREUR] Dossier $d introuvable" >&2; exit 2; }
    done
}

test_dossiers_clients() {
    local f="$CLIENTS/${PREFIXE}_c" u
    reussit C2 "comptable ${COMPTABLES[0]} cree un fichier dans dossiers_clients" "${COMPTABLES[0]}" touch "$f"
    reussit C2 "comptable ${COMPTABLES[1]} modifie le fichier de ${COMPTABLES[0]} (ACL par defaut)" \
        "${COMPTABLES[1]}" bash -c 'echo x >> "$1"' _ "$f"
    for u in "${DIRECTIONS[@]}"; do
        reussit C2 "direction $u lit dossiers_clients" "$u" cat "$f"
        refuse  C2 "direction $u ne modifie pas dossiers_clients" "$u" bash -c 'echo x >> "$1"' _ "$f"
        refuse  C2 "direction $u ne cree pas de fichier dans dossiers_clients" "$u" touch "$CLIENTS/${PREFIXE}_d"
    done
    for u in "${RHS[@]}" "${STAGIAIRES[@]}"; do
        refuse C2 "$u ne liste pas dossiers_clients" "$u" ls "$CLIENTS"
        refuse C2 "$u ne lit pas dossiers_clients" "$u" cat "$f"
    done
}

test_rh() {
    local f="$RH/${PREFIXE}_rh" u
    reussit C2 "rh ${RHS[0]} cree un fichier dans /srv/rh" "${RHS[0]}" touch "$f"
    reussit C2 "rh ${RHS[1]} modifie le fichier de ${RHS[0]}" "${RHS[1]}" bash -c 'echo x >> "$1"' _ "$f"
    for u in "${DIRECTIONS[@]}"; do
        reussit C2 "direction $u lit /srv/rh" "$u" cat "$f"
        refuse  C2 "direction $u ne modifie pas /srv/rh" "$u" bash -c 'echo x >> "$1"' _ "$f"
    done
    for u in "${COMPTABLES[@]}" "${STAGIAIRES[@]}"; do
        refuse C2 "$u ne liste pas /srv/rh" "$u" ls "$RH"
        refuse C2 "$u ne lit pas /srv/rh" "$u" cat "$f"
    done
}

test_commun() {
    local f="$COMMUN/${PREFIXE}_m" u
    reussit C2 "comptable ${COMPTABLES[0]} cree un fichier dans commun" "${COMPTABLES[0]}" touch "$f"
    for u in "${RHS[@]}" "${DIRECTIONS[@]}"; do
        reussit C2 "$u modifie un fichier de commun" "$u" bash -c 'echo x >> "$1"' _ "$f"
    done
    for u in "${STAGIAIRES[@]}"; do
        reussit C2 "stagiaire $u liste commun" "$u" ls "$COMMUN"
        reussit C2 "stagiaire $u lit commun" "$u" cat "$f"
        refuse  C2 "stagiaire $u ne modifie pas commun" "$u" bash -c 'echo x >> "$1"' _ "$f"
        refuse  C2 "stagiaire $u ne cree pas de fichier dans commun" "$u" touch "$COMMUN/${PREFIXE}_s_$u"
    done
}

test_depot() {
    local s1="${STAGIAIRES[0]}" s2="${STAGIAIRES[1]}" u
    local fs="$DEPOT/${PREFIXE}_stag" fc="$DEPOT/${PREFIXE}_compt"

    reussit C2 "stagiaire $s1 depose un fichier dans depot" "$s1" touch "$fs"
    refuse  C2 "stagiaire $s1 ne liste pas depot" "$s1" ls "$DEPOT"
    refuse  C2 "stagiaire $s2 ne liste pas depot" "$s2" ls "$DEPOT"
    refuse  C2 "stagiaire $s2 ne lit pas le fichier de $s1" "$s2" cat "$fs"
    refuse  C2 "stagiaire $s2 ne modifie pas le fichier de $s1" "$s2" bash -c 'echo x >> "$1"' _ "$fs"
    refuse  C2 "stagiaire $s2 ne supprime pas le fichier de $s1" "$s2" rm -f "$fs"
    if [[ -e $fs ]]; then
        ok C2 "le fichier de $s1 existe toujours"
    else
        ko C2 "le fichier de $s1 a disparu"
    fi

    for u in "${COMPTABLES[@]}" "${RHS[@]}" "${DIRECTIONS[@]}"; do
        reussit C2 "$u lit le fichier depose par $s1" "$u" cat "$fs"
        reussit C2 "$u ecrit dans le fichier depose par $s1" "$u" bash -c 'echo x >> "$1"' _ "$fs"
    done

    reussit C2 "comptable ${COMPTABLES[0]} cree un fichier dans depot" "${COMPTABLES[0]}" touch "$fc"
    refuse  C2 "stagiaire $s1 ne lit pas le fichier d'un comptable dans depot" "$s1" cat "$fc"
    refuse  C2 "stagiaire $s1 ne supprime pas le fichier d'un comptable" "$s1" rm -f "$fc"
}

test_prerequis
test_dossiers_clients
test_rh
test_commun
test_depot

echo "--- $OK / $TOTAL tests reussis"
(( OK == TOTAL )) && exit 0
exit 1
