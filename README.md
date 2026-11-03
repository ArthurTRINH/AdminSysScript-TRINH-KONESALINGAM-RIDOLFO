# AdminSysScript — Chiffres & Co

![Linux](https://img.shields.io/badge/OS-Linux-blue)
![Bash](https://img.shields.io/badge/Language-Bash-green)
![Git](https://img.shields.io/badge/Version_Control-Git-orange)
![Status](https://img.shields.io/badge/Status-In_Development-orange)

## 1. Présentation du projet

**AdminSysScript** est un projet d'administration et de sécurisation d'un serveur Linux réalisé dans le cadre de notre formation en cybersécurité à EFREI Paris.

Le projet repose sur un contexte professionnel fictif : le cabinet comptable **Chiffres & Co**.

L'objectif est de développer des scripts Bash permettant d'automatiser la gestion des utilisateurs, des groupes, des répertoires, des permissions et de la sécurité du serveur.

## 2. Membres du projet

- Trinh
- Konesalingam
- Ridolfo

## 3. Contexte professionnel

Le cabinet comptable est organisé en quatre groupes métier.

| Groupe | Utilisateurs |
|---|---|
| Comptables | darksasuke, garen |
| RH | hardstuckiron, freetoplay |
| Direction | imissher, roadtoplatine |
| Stagiaires | bigbot, gregoriz |

**Total : 8 utilisateurs et 4 groupes métier.**

## 4. Organisation des répertoires du serveur

Le serveur doit disposer de quatre répertoires principaux :

| Répertoire | Fonction | Propriétaire prévu |
|---|---|---|
| `/srv/dossiers_clients` | Gestion des dossiers clients | root:comptables |
| `/srv/rh` | Gestion des ressources humaines | root:rh |
| `/srv/commun` | Espace de travail partagé | root:comptables |
| `/srv/commun/depot` | Espace de dépôt de fichiers | root:comptables |

Ces répertoires sont créés automatiquement par le script `creer_comptes.sh`.

## 5. Matrice des permissions attendues

| Répertoire | Comptables | RH | Direction | Stagiaires |
|---|---|---|---|---|
| `/srv/dossiers_clients` | Lecture/Écriture | Aucun accès | Lecture | Aucun accès |
| `/srv/rh` | Aucun accès | Lecture/Écriture | Lecture | Aucun accès |
| `/srv/commun` | Lecture/Écriture | Lecture/Écriture | Lecture/Écriture | Lecture |
| `/srv/commun/depot` | Lecture/Écriture | Lecture/Écriture | Lecture/Écriture | Dépôt seul |

Les permissions détaillées (permissions classiques et ACL, y compris ACL par défaut) sont configurées par `creer_comptes.sh` et vérifiées par `tests_acl.sh`.

## 6. Travail réalisé

### Phase 1 — Préparation du projet

- Organisation de l'arborescence GitHub.
- Organisation des dossiers `config/` et `docs/`.
- Vérification des fichiers existants.
- Nettoyage des fichiers de test inutiles.
- Vérification du dépôt Git.
- Création et vérification du fichier `comptes.csv`.
- Définition des huit utilisateurs et des quatre groupes métier.

### Phase 2 — Gestion des comptes et des répertoires

#### Partie 3 — Création automatique des groupes et utilisateurs

Le script `creer_comptes.sh` a été développé pour :

- Vérifier que le script est exécuté avec les privilèges administrateur.
- Vérifier la présence des commandes nécessaires.
- Vérifier la présence et la structure du fichier `comptes.csv`.
- Créer les quatre groupes métier.
- Vérifier si les groupes existent déjà.
- Créer les huit comptes utilisateurs.
- Définir les groupes principaux.
- Ajouter les groupes secondaires lorsqu'ils sont renseignés.
- Détecter les utilisateurs déjà existants et mettre à jour leur groupe principal.

#### Partie 4 — Création de l'arborescence des répertoires

Le script permet également de :

- Créer `/srv/dossiers_clients`.
- Créer `/srv/rh`.
- Créer `/srv/commun`.
- Créer `/srv/commun/depot`.
- Définir les propriétaires et groupes associés.
- Afficher les informations des utilisateurs et des répertoires après configuration.

### 6.1 Fonctionnement de creer_comptes.sh

Le script est organisé en plusieurs étapes :

1. Vérification des privilèges administrateur.
2. Vérification des commandes nécessaires.
3. Localisation et vérification du fichier CSV.
4. Création des groupes métier.
5. Création ou mise à jour des utilisateurs.
6. Création des répertoires.
7. Attribution des propriétaires et groupes.
8. Vérification finale des utilisateurs et répertoires.

### 6.2 Commandes Linux utilisées

| Commande | Utilisation |
|---|---|
| `groupadd` | Création des groupes |
| `getent` | Vérification de l'existence des groupes |
| `useradd` | Création des utilisateurs |
| `usermod` | Modification des comptes et groupes |
| `id` | Vérification des utilisateurs et groupes |
| `mkdir -p` | Création des répertoires |
| `chown` | Attribution des propriétaires et groupes |
| `awk` | Vérification de la structure du CSV |
| `tail` | Ignorer l'en-tête du CSV |
| `ls -ld` | Affichage des informations des répertoires |

## 7. Fichier comptes.csv

Le fichier `comptes.csv` centralise les informations des utilisateurs.

Format utilisé :

```csv
login;nom;groupe_principal;groupes_secondaires
darksasuke;darksasuke;comptables;
garen;garen;comptables;
hardstuckiron;hardstuckiron;rh;
freetoplay;freetoplay;rh;
imissher;imissher;direction;
roadtoplatine;roadtoplatine;direction;
bigbot;bigbot;stagiaire;
gregoriz;gregoriz;stagiaire;
```

Le séparateur utilisé est le point-virgule `;`.

## 8. Vérifications réalisées

Le script `creer_comptes.sh` a passé les vérifications statiques suivantes sur Kali Linux :

| Vérification | Résultat |
|---|---|
| `bash -n creer_comptes.sh` | Réussi |
| `shellcheck creer_comptes.sh` | Réussi |
| Vérification de l'en-tête CSV | Réussie |
| Vérification des quatre colonnes | Réussie |
| Vérification des huit utilisateurs | Réussie |
| Vérification des quatre groupes | Réussie |

**Important :** les tests fonctionnels de création des comptes et des répertoires sur le serveur cible restent à effectuer. La validation syntaxique ne garantit pas encore le fonctionnement complet du script.

## 9. Arborescence actuelle du projet

```text
AdminSysScript-TRINH-KONESALINGAM-RIDOLFO/
│
├── README.md
├── DOSSIER.md
├── comptes.csv
│
├── installer.sh
├── creer_comptes.sh

├── tests_acl.sh
├── comptes.csv
├── docs/
│   └── resultats_tests_acl.txt
└── README.md 
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

## 10. Technologies utilisées

- Linux : environnement serveur.
- Bash : automatisation des tâches.
- Git et GitHub : gestion du code et collaboration.
- ACL : gestion avancée des permissions.
- SSH : administration distante sécurisée.
- Fail2ban : protection contre les tentatives de connexion.
- nftables : filtrage réseau.
- systemd-journald : gestion des journaux système.

## 11. État d'avancement

### Phase 1 — Préparation du projet
- [x] Organisation du dépôt GitHub.
- [x] Préparation de l'arborescence.
- [x] Nettoyage des fichiers de test.
- [x] Vérification du CSV.
- [x] Définition des utilisateurs et groupes.

### Phase 2 — Gestion des comptes et permissions
- [x] Développement du script de création des comptes.
- [x] Développement de la création des répertoires.
- [x] Tests fonctionnels sur le serveur cible.
- [x] Configuration des permissions ACL.
- [x] Vérification des droits d'accès.

### Phase 3 — Sécurisation du serveur
- [ ] Sécurisation SSH.
- [ ] Configuration Fail2ban.
- [ ] Configuration nftables.
- [ ] Configuration journald.

### Phase 4 — Automatisation et surveillance
- [ ] Sauvegarde et restauration.
- [ ] Analyse des journaux.
- [ ] Automatisation de l'installation.

### Phase 5 — Tests et livraison
- [ ] Tests globaux.
- [ ] Documentation finale.
- [ ] Validation du projet.
- [ ] Préparation de la présentation.

## 12. Installation et utilisation

Le projet est actuellement en développement.

Le script de création des comptes doit être exécuté sur le serveur Linux cible avec les privilèges administrateur.

Commande prévue :

```bash
sudo ./creer_comptes.sh
```

Ne pas exécuter cette commande sur une machine de développement sans avoir vérifié les conséquences sur ses comptes et ses répertoires système.

## 13. Sécurité

- Ne jamais stocker de mots de passe en clair dans le dépôt.
- Ne jamais publier de clés privées SSH.
- Respecter le principe du moindre privilège.
- Limiter les accès selon les fonctions des utilisateurs.
- Vérifier les permissions des répertoires.
- Prévoir des sauvegardes régulières.

---

**AdminSysScript — Cabinet comptable Chiffres & Co**

Projet étudiant — EFREI Paris  
Développement en cours.
