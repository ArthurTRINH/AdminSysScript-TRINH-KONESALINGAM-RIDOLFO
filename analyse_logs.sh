#!/bin/bash
# analyse_logs.sh - rapport des connexions SSH echouees et reussies (J4)
# Usage : sudo analyse_logs.sh [-s SEUIL] [-H HEURES]
#   -s SEUIL  : alerte si une IP a plus de SEUIL connexions echouees (defaut 5)
#   -H HEURES : periode analysee, de 1 a 8760 (defaut 24)
# Codes : 0 = OK, 1 = seuil depasse, 2 = erreur d'utilisation
# Lance en root par support via sudo : le script doit appartenir a root (0755),
# et journalctl doit avoir --no-pager (un pager lance en root donne un shell root).

set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin

SEUIL=5
HEURES=24

usage() { echo "Usage : $0 [-s SEUIL] [-H HEURES]" >&2; exit 2; }

while getopts ":s:H:h" opt; do
    case "$opt" in
        s) SEUIL="$OPTARG" ;;
        H) HEURES="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -eq 0 ]] || usage

# seuls des entiers sont acceptes (support peut choisir les arguments)
[[ $SEUIL =~ ^[0-9]{1,6}$ ]] || { echo "[ERREUR] SEUIL doit etre un entier" >&2; exit 2; }
[[ $HEURES =~ ^[0-9]{1,4}$ ]] && (( 10#$HEURES >= 1 && 10#$HEURES <= 8760 )) \
    || { echo "[ERREUR] HEURES doit etre un entier entre 1 et 8760" >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo "[ERREUR] Lancer en root : sudo $0" >&2; exit 2; }

journal="$(journalctl -u ssh.service --since "-${HEURES}h" --no-pager -o short-iso -q)" \
    || { echo "[ERREUR] Lecture du journal impossible" >&2; exit 2; }

# Une connexion = un processus sshd-session[PID]. Elle est "echouee" si elle a un message
# d'echec et aucun "Accepted" : on compte des connexions, pas des lignes.
rapport="$(printf '%s\n' "$journal" | awk -v seuil="$SEUIL" '
    function apres(mot,   i) {          # mot qui suit "mot" dans le message
        for (i = 1; i < n; i++) if (w[i] == mot) return w[i + 1]
        return ""
    }
    {
        proc = $3
        if (proc !~ /^sshd/) next
        msg = $0
        sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", msg)
        n = split(msg, w, " ")
        user = ""; ip = ""; echec = 0

        if (msg ~ /^Accepted [^ ]+ for /) {
            user = apres("for"); ip = apres("from")
            ok[proc] = 1
            reussies[++nb_ok] = $1 "  " user "  depuis " ip "  (" w[2] ")"
            next
        }
        if (msg ~ /^Failed / || msg ~ /^maximum authentication attempts exceeded/) {
            user = apres("for"); if (user == "invalid") user = apres("user")
            ip = apres("from"); echec = 1
        } else if (msg ~ /^Invalid user /) {
            user = w[3]; if (user == "from") user = "(vide)"
            ip = apres("from"); echec = 1
        } else if (msg ~ /^User .* not allowed because/) {
            user = w[2]; ip = apres("from"); echec = 1
        } else if (msg ~ /^(Connection closed by|Disconnected from) (authenticating|invalid) user .*\[preauth\]/) {
            user = apres("user"); ip = w[n - 3]; echec = 1
        }
        if (echec && !(proc in ip_de)) { ip_de[proc] = ip; user_de[proc] = user }
    }
    END {
        for (p in ip_de) {
            if (p in ok) continue
            par_ip[ip_de[p]]++; par_user[user_de[p]]++; total++
        }
        print "--- Connexions echouees par adresse IP ---"
        max = 0
        for (i in par_ip) {
            alerte = (par_ip[i] > seuil) ? "   <-- ALERTE (seuil " seuil ")" : ""
            printf "  %6d  %s%s\n", par_ip[i], i, alerte
            if (par_ip[i] > max) max = par_ip[i]
        }
        if (total == 0) print "  aucune"
        print ""
        print "--- Comptes vises par les connexions echouees ---"
        for (u in par_user) printf "  %6d  %s\n", par_user[u], u
        if (total == 0) print "  aucun"
        print ""
        print "--- Connexions reussies ---"
        for (k = 1; k <= nb_ok; k++) print "  " reussies[k]
        if (nb_ok == 0) print "  aucune"
        print ""
        printf "Total : %d connexion(s) echouee(s), %d reussie(s)\n", total, nb_ok
        print "__MAX__ " max
    }
')"

max="$(printf '%s\n' "$rapport" | awk '$1 == "__MAX__" { print $2 }')"

echo "=========================================================="
echo " RAPPORT SSH - $(hostname) - $(date '+%Y-%m-%d %H:%M')"
echo " Periode : ${HEURES} h   |   Seuil : > ${SEUIL} echecs par IP"
echo "=========================================================="
printf '%s\n' "$rapport" | grep -v '^__MAX__' || true

if (( ${max:-0} > SEUIL )); then
    echo "[ALERTE] Une adresse IP depasse le seuil (${max} > ${SEUIL})."
    exit 1
fi
echo "[OK] Aucune adresse IP ne depasse le seuil."
