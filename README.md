# AdminSysScript — Chiffres & Co

Projet XTI302-CYB (EFREI Paris) : durcir un serveur Debian 13 minimal, automatiser sa configuration par des scripts et la prouver avec `verifier.sh`.

Contexte choisi : B — cabinet comptable Chiffres & Co. Trinôme : Trinh, Konesalingam, Ridolfo.

## Contenu du dépôt

```text
.
├── README.md                 ce fichier
├── DOSSIER.md                dossier (conformité, choix techniques, défense, restauration)
├── comptes.csv               comptes et groupes (login;nom;groupe_principal;groupes_secondaires)
├── installer.sh              reconstruit toute la configuration sur une Debian vierge
├── creer_comptes.sh          comptes, groupes, clés SSH, /srv, droits et ACL (C1, C2, C4)
├── preparer_disque.sh        formate UNE fois le second disque (manuel, avec confirmation)
├── analyse_logs.sh           rapport des connexions SSH, code 1 si seuil dépassé (J4)
├── sauvegarde.sh             sauvegarde rsync incrémentale versionnée (B1 à B3)
├── verifier.sh               teste chaque exigence : [OK]/[KO]
├── tests_acl.sh              tests détaillés des droits sur /srv (C2)
├── config/
│   ├── ssh/sshd_config.d/00-hardening.conf   S1 à S5
│   ├── sudoers.d/admins, support             C3
│   ├── fail2ban/jail.d/sshd.conf             J1
│   ├── nftables.conf                         J2
│   ├── journald.conf                         J3
│   ├── apt/20auto-upgrades                   D1
│   ├── systemd/sauvegarde.{service,timer}    B2
│   ├── suid_attendus.txt                     D3
│   └── keys/<login>.pub                      clés publiques des comptes de acces_ssh
└── docs/
    ├── restauration.md                       B4
    └── resultats_tests_acl.txt
```

## Prérequis

- Une VM Debian 13 minimale avec SSH et un second disque de 1 à 2 Go.
- Les clés publiques des comptes de `acces_ssh` dans `config/keys/` (jamais de clé privée).
- Uniquement des paquets des dépôts Debian officiels (installés par `installer.sh`).

## Installation

Depuis le dossier du dépôt copié sur la Debian :

```bash
sudo ./preparer_disque.sh /dev/sdb     # une seule fois, demande une confirmation
sudo ./installer.sh                    # passage 1 : comptes, services, SSH
sudo passwd trinh                      # mot de passe sudo d'au moins un admin
# tester dans un 2e terminal : ssh -i ~/.ssh/chiffres_trinh trinh@192.168.56.101 puis sudo -v
sudo ./installer.sh                    # passage 2 : verrouille root, retire les autres comptes de sudo
```

`installer.sh` peut être relancé sans danger. Il ne formate jamais de disque.

## Vérification

```bash
sudo ./verifier.sh ; echo "code : $?"
```

Une ligne `[OK]` ou `[KO]` par test, puis `--- N / M tests réussis`. Code de sortie 0 si tout est conforme.

## État d'avancement

Ne cocher qu'avec une preuve (sortie de `verifier.sh` sur la VM).

- [x] `installer.sh` testé sur la VM
- [x] `verifier.sh` : tous les tests [OK]
- [] `installer.sh` testé depuis le snapshot vierge, puis relancé une 2e fois
- [x] Bannissement fail2ban testé depuis l'hôte
- [x] Restauration testée (docs/restauration.md complété)
- [x] DOSSIER.md complété (numéros ANSSI vérifiés)

## Sécurité

- Aucun mot de passe ni clé privée dans le dépôt.
- Les scripts lancés en root sont dans `/usr/local/sbin`, appartiennent à root et ne sont modifiables que par lui.
