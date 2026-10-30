# AdminSysScript-TRINH-KONESALINGAM-RIDOLFO
# AdminSysScript — Chiffres & Co

![Linux](https://img.shields.io/badge/OS-Linux-blue)
![Shell](https://img.shields.io/badge/Language-Bash-green)
![Project](https://img.shields.io/badge/Project-In%20Progress-orange)

## Présentation du projet

**AdminSysScript** est un projet d'administration et de sécurisation d'un serveur Linux réalisé dans le cadre de notre formation en cybersécurité à EFREI Paris.

Le projet repose sur un contexte professionnel fictif : le cabinet comptable **Chiffres & Co**.

L'objectif est de développer un ensemble de scripts Bash permettant d'automatiser l'administration du serveur, la gestion des utilisateurs, les permissions d'accès, la sécurisation des services et la surveillance du système.

## Membres du projet

- Trinh
- Konesalingam
- Ridolfo

## Contexte : Chiffres & Co

Le cabinet est organisé autour de quatre groupes métier :

| Groupe | Utilisateurs |
|---|---|
| Comptables | darksasuke, garen |
| RH | hardstuckiron, freetoplay |
| Direction | imissher, roadtoplatine |
| Stagiaires | bigbot, gregoriz |

Au total, huit utilisateurs métier sont définis dans le fichier `comptes.csv`.

## Gestion des répertoires et des permissions

Le serveur devra disposer de quatre espaces principaux :

| Répertoire | Fonction |
|---|---|
| `/srv/dossiers_clients` | Gestion des dossiers clients |
| `/srv/rh` | Gestion des ressources humaines |
| `/srv/commun` | Espace de travail partagé |
| `/srv/commun/depot` | Espace de dépôt de fichiers |

### Matrice des permissions

| Répertoire | Comptables | RH | Direction | Stagiaires |
|---|---|---|---|---|
| `/srv/dossiers_clients` | Lecture/Écriture | Aucun accès | Lecture | Aucun accès |
| `/srv/rh` | Aucun accès | Lecture/Écriture | Lecture | Aucun accès |
| `/srv/commun` | Lecture/Écriture | Lecture/Écriture | Lecture/Écriture | Lecture |
| `/srv/commun/depot` | Lecture/Écriture | Lecture/Écriture | Lecture/Écriture | Dépôt seul |

Les permissions seront gérées avec les groupes Linux, les permissions classiques et les ACL (Access Control Lists).

## Arborescence du projet

```text
AdminSysScript-TRINH-KONESALINGAM-RIDOLFO/
│
├── README.md
├── DOSSIER.md
├── comptes.csv
│
├── installer.sh
├── creer_comptes.sh
├── analyse_logs.sh
├── sauvegarde.sh
├── verifier.sh
│
├── config/
│   ├── fail2ban/
│   │   └── jail.d/
│   │       └── sshd.conf
│   │
│   ├── ssh/
│   │   └── sshd_config.d/
│   │       └── hardening.conf
│   │
│   ├── sudoers.d/
│   │   └── admins
│   │
│   ├── keys/
│   ├── nftables.conf
│   └── journald.conf
│
└── docs/
    └── restauration.md
```

## Description des scripts

| Fichier | Fonction |
|---|---|
| `comptes.csv` | Contient les informations des utilisateurs et de leurs groupes |
| `creer_comptes.sh` | Création des groupes, utilisateurs et répertoires |
| `verifier.sh` | Vérification des permissions et des accès |
| `installer.sh` | Automatisation de l'installation et de la configuration |
| `analyse_logs.sh` | Analyse des journaux système et SSH |
| `sauvegarde.sh` | Gestion des sauvegardes et de la restauration |

Les scripts sont en cours de développement. Leur fonctionnement et leurs options seront documentés au fur et à mesure de leur validation.

## Technologies utilisées

- **Linux** : environnement serveur.
- **Bash** : automatisation des tâches d'administration.
- **Git et GitHub** : gestion du code source et travail collaboratif.
- **ACL** : gestion avancée des permissions.
- **SSH** : administration distante sécurisée.
- **Fail2ban** : protection contre les tentatives de connexion répétées.
- **nftables** : filtrage réseau.
- **systemd-journald** : gestion des journaux système.

## Installation et utilisation

Le projet est actuellement en développement.

Les procédures d'installation et d'exécution seront ajoutées après validation des scripts.

L'objectif sera de permettre le lancement de la configuration avec les privilèges administrateur sur le serveur cible.

## Sécurité

Quelques règles de sécurité appliquées au projet :

- Ne jamais stocker de mots de passe en clair dans le dépôt GitHub.
- Ne jamais publier de clés privées SSH.
- Limiter les privilèges des utilisateurs selon leur fonction.
- Vérifier les permissions des répertoires.
- Contrôler les journaux système.
- Prévoir des sauvegardes et une procédure de restauration.

## État d'avancement

Le projet est organisé en cinq phases :

- [x] Phase 1 — Préparation du projet
- [ ] Phase 2 — Gestion des comptes et permissions
- [ ] Phase 3 — Sécurisation du serveur
- [ ] Phase 4 — Automatisation et surveillance
- [ ] Phase 5 — Tests et livraison

**Projet en cours de réalisation.**

---

*AdminSysScript — Cabinet comptable Chiffres & Co*  
*Projet étudiant — EFREI Paris*
