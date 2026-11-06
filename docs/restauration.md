# Restauration d'une sauvegarde (B4)

## 1. Principe

`sauvegarde.sh` crée chaque nuit (timer systemd, 02:30) une version datée de `/srv` et `/etc` sur le second disque, monté sur `/sauvegardes` :

```text
/sauvegardes/versions/2026-11-06_023000/srv/...
/sauvegardes/versions/2026-11-06_023000/etc/...
/sauvegardes/versions/derniere -> 2026-11-06_023000
```

Chaque version est complète. Les fichiers inchangés sont des liens physiques vers la version précédente (`rsync --link-dest`), ils ne prennent pas de place en plus. Les 7 dernières versions sont gardées. Les droits, propriétaires, ACL et attributs étendus sont conservés (`rsync -aAXH`).

Seuls `root` et le groupe `admins` entrent dans `/sauvegardes` (`root:admins 0750`) : la restauration se fait avec un compte admin, via `sudo`.

## 2. Restaurer un fichier

Exemple : `/srv/dossiers_clients/bilan_client42.txt` a été écrasé par erreur, puis supprimé.

**Étape 1 : vérifier que le disque est monté**

```bash
findmnt /sauvegardes
```

**Étape 2 : trouver les versions qui contiennent le fichier**

```bash
F=srv/dossiers_clients/bilan_client42.txt
for v in /sauvegardes/versions/20*/; do
    sudo test -f "$v$F" && echo "$(basename "$v")  $(sudo stat -c '%y %s octets' "$v$F")"
done
```

On choisit la dernière version avant l'erreur. Pour voir le contenu : `sudo cat /sauvegardes/versions/2026-11-06_023000/$F`

**Étape 3 : simuler (rien n'est modifié)**

```bash
V=/sauvegardes/versions/2026-11-06_023000
sudo rsync -aAX --dry-run -v "$V/$F" /srv/dossiers_clients/
```

**Étape 4 : restaurer**

```bash
sudo rsync -aAX "$V/$F" /srv/dossiers_clients/
```

`-a` garde propriétaire, groupe, droits et dates, `-A` les ACL, `-X` les attributs étendus. Pour ne pas écraser une version récente, restaurer sous un autre nom : `sudo rsync -aAX "$V/$F" /srv/dossiers_clients/bilan_client42.restaure.txt`

**Étape 5 : vérifier**

```bash
ls -l /srv/dossiers_clients/bilan_client42.txt
getfacl -p /srv/dossiers_clients/bilan_client42.txt
sudo -u imissher cat /srv/dossiers_clients/bilan_client42.txt
```

## 3. Restaurer un dossier entier

```bash
sudo rsync -aAXH --dry-run -v "$V/srv/rh/" /srv/rh/
sudo rsync -aAXH "$V/srv/rh/" /srv/rh/
```

Sans `--delete`, les fichiers créés depuis la sauvegarde sont gardés. Avec `--delete`, le dossier redevient identique à la version.

## 4. Test réalisé

> À COMPLÉTER avec votre test sur la VM : date, commandes et sorties obtenues.

Scénario :

1. `darksasuke` crée `bilan_client42.txt` ("bilan 2025 v1"), puis `sudo systemctl start sauvegarde.service` (version A).
2. `garen` écrase le fichier ("ECRASE PAR ERREUR"), nouvelle sauvegarde (version B), puis on supprime le fichier.
3. La boucle de l'étape 2 trouve le fichier dans A et B.
4. On restaure depuis A, puis on vérifie le contenu, le propriétaire `darksasuke:comptables` et l'ACL (`group:direction:r-x`).

Résultat observé : À COMPLÉTER

## 5. Limites

- Le disque de sauvegarde est dans la même machine : une panne, un vol ou un rançongiciel avec les droits root peuvent le détruire aussi (règle 3-2-1 non respectée).
- Les sauvegardes ne sont pas chiffrées : elles sont protégées par les droits (`0750 root:admins`) et le montage `nodev,nosuid,noexec`.
- Avec 7 versions quotidiennes, on ne remonte pas au-delà d'une semaine.
