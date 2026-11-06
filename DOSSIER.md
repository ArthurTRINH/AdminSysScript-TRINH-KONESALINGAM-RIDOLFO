# Dossier — AdminSysScript, Chiffres & Co (contexte B)

> Brouillon : remplacer chaque « À COMPLÉTER » par vos résultats réels. Les numéros ANSSI-BP-028 sont à relever dans le guide officiel (lien en bas). Chaque membre doit pouvoir défendre ces justifications à l'oral.

## 1. Tableau de conformité

| ID | Ce que nous avons fait | Test dans verifier.sh | ANSSI |
|---|---|---|---|
| C1 | `creer_comptes.sh` lit `comptes.csv`, crée les groupes et comptes s'ils n'existent pas, sinon les met à jour : relançable sans doublon | `test_C1` | À COMPLÉTER |
| C2 | `/srv/*` : propriétaire root, `chmod 2770` (setgid), `depot` en `3770` (sticky), ACL de groupe + ACL par défaut | `test_C2` : accès permis et refusés testés avec les vrais comptes | À COMPLÉTER |
| C3 | `admins` : `ALL=(ALL:ALL) ALL` ; `support` : uniquement `analyse_logs.sh` ; `vboxuser` retiré du groupe `sudo` | `test_C3` | À COMPLÉTER |
| C4 | `passwd -l root` ; homes en `0700` et `HOME_MODE 0700` | `test_C4` | À COMPLÉTER |
| S1 | `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, clé publique seule | `test_S1` : `sshd -T` + vraie connexion sans clé refusée | À COMPLÉTER |
| S2 | `PermitRootLogin no` | `test_S2` | À COMPLÉTER |
| S3 | `AllowGroups acces_ssh` | `test_S3` : connexion réelle d'un comptable refusée | À COMPLÉTER |
| S4 | `MaxAuthTries 3`, `ChannelTimeout session=15m` | `test_S4` | – |
| S5 | `/etc/ssh/sshd_config.d/00-hardening.conf`, `sshd -t` avant `reload` | `test_S5` | – |
| J1 | jail `sshd` : backend systemd, 3 échecs / 10 min, bannissement 1 h via nftables | `test_J1` | À COMPLÉTER |
| J2 | `nftables.conf` : policy drop en entrée, established/related, lo, tcp/22 ; sans `flush ruleset` | `test_J2` | À COMPLÉTER |
| J3 | `Storage=persistent` (`journald.conf.d/99-chiffres-co.conf`) | `test_J3` | À COMPLÉTER |
| J4 | `analyse_logs.sh` : échecs par IP, comptes visés, réussites ; code 1 si seuil dépassé | `test_J4` | – |
| B1 | `sauvegarde.sh` : `rsync -aAXH --link-dest`, versions datées sur le second disque, 7 versions | `test_B1` | À COMPLÉTER |
| B2 | `sauvegarde.timer` (02:30), journalisation `logger -t sauvegarde` | `test_B2` | – |
| B3 | `/sauvegardes` en `root:admins 0750`, montage `nodev,nosuid,noexec` | `test_B3` | – |
| B4 | Procédure dans `docs/restauration.md` | `test_B4` | – |
| D1 | `unattended-upgrades` + `20auto-upgrades` | `test_D1` | À COMPLÉTER |
| D2 | Seul sshd écoute (le pare-feu bloque le reste) | `test_D2` | À COMPLÉTER |
| D3 | Recherche limitée aux systèmes de fichiers réels ; SUID listés dans `config/suid_attendus.txt` | `test_D3` | À COMPLÉTER |

Résultat de `verifier.sh` sur la VM reconstruite : À COMPLÉTER (`--- N / M tests réussis`).

## 2. Choix techniques

**Comptes et droits.** Comptes nominatifs pour les admins (on sait qui a fait quoi avec `sudo`). Leur mot de passe sert uniquement à `sudo` : une clé SSH volée ne suffit pas pour devenir root. `support` n'a pas de mot de passe, d'où le `NOPASSWD` limité à un seul script (chemin absolu). `analyse_logs.sh` appartient à root en `0755` : si `support` pouvait le modifier, il obtiendrait un shell root. Le script utilise `journalctl --no-pager` car un pager lancé en root permet d'ouvrir un shell.

**Dossier dépôt.** Le stagiaire a `-wx` : il peut déposer un fichier mais pas lister. L'ACL par défaut lui donne `---` sur chaque nouveau fichier. Le sticky bit l'empêche de supprimer les fichiers des autres. On n'a pas désactivé `fs.protected_regular` : les tests utilisent `dd conv=nocreat`, qui teste les droits sans affaiblir le noyau.

**SSH.** `MaxAuthTries 3` : À COMPLÉTER (justification). `ClientAliveInterval` ne ferme pas une session inactive, d'où `ChannelTimeout session=15m` (OpenSSH ≥ 9.2). Le fichier s'appelle `00-…` car sshd garde la première valeur lue.

**fail2ban.** 3 échecs en 10 min, bannissement 1 h : À COMPLÉTER (compromis entre bloquer une attaque et ne pas pénaliser une erreur de frappe). Backend `systemd` car Debian 13 minimale n'a pas `auth.log`.

**nftables.** Pas de `flush ruleset` : il effacerait les bans de fail2ban. Rechargement par `systemctl reload nftables`, jamais `restart`. À CONFIRMER par votre test : la table `f2b-table` survit au rechargement.

**Journal.** À COMPLÉTER (durée et taille choisies, et pourquoi).

**Seuil d'analyse.** Plus de 5 connexions échouées par IP sur 24 h : À COMPLÉTER (justification).

**Sauvegardes.** `rsync --link-dest` : versions complètes mais légères (liens physiques). L'écriture se fait dans `*.incomplete` puis la version est renommée : une sauvegarde interrompue n'est jamais prise pour valide. 7 versions = une semaine de retour arrière. Correctif dans le script, à confirmer par `test_B1` : rsync perd l'entrée `group::` de l'ACL des dossiers sticky (`depot`), le script la recopie depuis la source. `installer.sh` ne formate jamais : `preparer_disque.sh` le fait une fois, après confirmation.

**Écoutes réseau (D2).** À COMPLÉTER avec la sortie de `ss -tulpn`.

## 3. Défense

| Attaque | Ce qui la rend plus difficile | Ce qui n'est pas couvert |
|---|---|---|
| Force brute SSH | Pas de mot de passe accepté, 3 essais, fail2ban bannit l'IP 1 h | Attaque répartie sur beaucoup d'IP |
| Vol du mot de passe d'un employé | Inutile en SSH : clé obligatoire et `AllowGroups` | Accès physique / console |
| Vol de la clé privée d'un admin | Mot de passe encore demandé pour `sudo` | Clé sans phrase de passe, keylogger |
| Utilisateur curieux (RH qui lit les dossiers clients) | Droits et ACL de `/srv`, homes en 700, sauvegardes en 750 | Un admin peut tout lire |
| Compte stagiaire compromis | Ne liste ni ne lit `depot`, pas de sudo, pas de SSH | Fichiers malveillants déposés dans `depot` |
| Rançongiciel / suppression | Versions datées sur un disque séparé, réservé aux admins | Attaquant root : même machine, pas de 3-2-1 |

## 4. Restauration

Voir `docs/restauration.md` : trouver la version, simuler avec `--dry-run`, restaurer avec `rsync -aAX`, vérifier avec `getfacl`.

## Références

- ANSSI, *Recommandations de configuration d'un système GNU/Linux* (ANSSI-BP-028) : https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-un-systeme-gnulinux
- ANSSI, *Usage sécurisé d'(Open)SSH* : https://messervices.cyber.gouv.fr/guides/usage-securise-dopenssh
- Manuels : sshd_config(5), sudoers(5), setfacl(1), nft(8), jail.conf(5), rsync(1), systemd.timer(5), journald.conf(5)
