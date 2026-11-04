#!/bin/bash

LOG_FILE="/var/log/auth.log"

if [ ! -f "$LOG_FILE" ]; then
    LOG_FILE="/var/log/syslog"
fi

echo "=== RAPPORT D'ANALYSE DES CONNEXIONS SSH ==="
echo "Date : $(date)"
echo ""

echo "[*] Tentatives de connexions échouées (Failed passwords) :"
grep "Failed password" "$LOG_FILE" | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr

echo ""
echo "[*] Connexions SSH réussies :"
grep "Accepted" "$LOG_FILE" | awk '{print "Utilisateur:", $(NF-5), "depuis", $(NF-2)}'
