# audit-bitwarden-shai-hulud

Outils d'audit pour la compromission de supply-chain `@bitwarden/cli@2026.4.0`
(**Shai-Hulud: The Third Coming**) — détection locale et sur GitHub Actions.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7.6+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Bash](https://img.shields.io/badge/Shell-Bash%205%2B-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub Actions](https://img.shields.io/badge/GitHub-Actions-2088FF.svg)](https://github.com/features/actions)

---

## Table des matières

- [Contexte de l'incident](#contexte-de-lincident)
- [Ce que fait ce repo](#ce-que-fait-ce-repo)
- [Structure du projet](#structure-du-projet)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
  - [Script PowerShell — Windows 11](#script-powershell--windows-11)
  - [Script Bash — Linux et macOS](#script-bash--linux-et-macos)
  - [GitHub Actions — scan multi-repos](#github-actions--scan-multi-repos)
- [Configuration avancée](#configuration-avancée)
  - [Modes de sélection des repos](#modes-de-sélection-des-repos)
  - [Export du rapport JSON](#export-du-rapport-json)
  - [Dry-run](#dry-run)
- [Ce que détectent les scripts](#ce-que-détectent-les-scripts)
- [Actions à mener si compromis](#actions-à-mener-si-compromis)
- [FAQ](#faq)
- [Contribuer](#contribuer)
- [Licence](#licence)

---

## Contexte de l'incident

Le **22 avril 2026**, entre 17h57 et 19h30 (heure de New York — UTC-4), le
package npm `@bitwarden/cli` dans sa version `2026.4.0` a été compromis via une
attaque de **supply-chain** ciblant le pipeline GitHub Actions de Bitwarden.

Durant cette fenêtre de **93 minutes**, 334 téléchargements ont été effectués
avant que l'équipe sécurité de Bitwarden ne détecte l'anomalie et retire le
package.

### Le malware : Shai-Hulud: The Third Coming

Le payload, baptisé **"Shai-Hulud: The Third Coming"** (troisième vague d'une
campagne entamée en septembre 2025), se comporte comme un ver de
credential-stealing. Il est obfusqué dans un fichier `bw1.js` exécuté via un
hook `preinstall` npm.

Une fois actif, il exfiltre les données suivantes, chiffrées en AES-256-GCM,
vers un domaine imitant Checkmarx (`audit.checkmarx[.]cx`) :

- Tokens GitHub (`ghp_*`)
- Tokens npm
- Credentials AWS (`~/.aws/`)
- Tokens Azure
- Clés SSH (`~/.ssh/`)
- Fichiers `.npmrc`
- Configurations Claude et MCP
- Secrets CI/CD présents dans l'environnement

Le malware tente également de se propager en injectant du code dans d'autres
packages npm locaux et en modifiant des workflows GitHub Actions existants.

**Signature visuelle :** les dépôts publics créés par le malware chez les
victimes portent des noms tirés de l'univers de *Dune* :
`atreides`, `fremen`, `sardaukar`, `harkonnen`.

### Ce qui n'est PAS impacté

- Les coffres utilisateur Bitwarden (chiffrés côté client, non exposés)
- Les extensions navigateur Bitwarden
- Les applications desktop et mobiles Bitwarden
- Le package snap Bitwarden

Seules les machines ayant installé `@bitwarden/cli@2026.4.0` via npm
**pendant la fenêtre de compromission** sont potentiellement exposées.

### Références

- [Déclaration officielle Bitwarden](https://community.bitwarden.com/t/bitwarden-statement-on-checkmarx-supply-chain-incident/96127)
- [Analyse technique — Socket.dev](https://socket.dev/blog/bitwarden-cli-compromised)
- [Analyse technique — Aikido.dev](https://www.aikido.dev/blog/shai-hulud-npm-bitwarden-cli-compromise)
- [Analyse — EndorLabs](https://www.endorlabs.com/learn/shai-hulud-the-third-coming----inside-the-bitwarden-cli-2026-4-0-supply-chain-attack)
- [Article Korben](https://korben.info/bitwarden-cli-compromis-checkmarx-shai-hulud.html)

---

## Ce que fait ce repo

Ce repo fournit **trois outils complémentaires** pour détecter rapidement toute
trace de la compromission sur vos machines et dans vos dépôts GitHub :

| Outil | Environnement | Fichier |
| --- | --- | --- |
| Script PowerShell | Windows 11 (local) | `Audit-BitwardenShaiHulud.ps1` |
| Script Bash | Linux / macOS / WSL | `audit-bitwarden-shai-hulud.sh` |
| Workflow GitHub Actions | Multi-repos (CI) | `.github/workflows/audit-bitwarden-2026.4.0.yml` |

Les trois outils vérifient les mêmes vecteurs d'attaque :

- Présence du package npm compromis (global et local)
- Présence des fichiers malware (`bw1.js`, `bw_setup.js`)
- Traces du domaine C2 dans les historiques et logs
- Backdoors injectées dans les profils shell / PowerShell
- Workflows GitHub Actions altérés par le ver

---

## Structure du projet

```text
audit-bitwarden-shai-hulud/
├── .github/
│   └── workflows/
│       └── audit-bitwarden-2026.4.0.yml   # Workflow GitHub Actions
├── Audit-BitwardenShaiHulud.ps1            # Script PowerShell (Windows 11)
├── audit-bitwarden-shai-hulud.sh           # Script Bash (Linux / macOS)
├── LICENSE
└── README.md
```

---

## Prérequis

### Pour le script PowerShell

| Prérequis | Version minimale | Notes |
| --- | --- | --- |
| Windows | 11 | Testé sur Windows 11 Enterprise |
| PowerShell | 7.6.1+ | Téléchargeable sur [GitHub](https://github.com/PowerShell/PowerShell/releases) |
| npm | Toute version | Optionnel — vérifications npm ignorées si absent |

> Le script est compatible PowerShell 5.1 (natif Windows) mais l'usage de
> PowerShell 7.6.1+ est fortement recommandé pour la gestion des erreurs et la
> lisibilité de la sortie.

### Pour le script Bash

| Prérequis | Version minimale | Notes |
| --- | --- | --- |
| Bash | 5.0+ | Utilise `mapfile` (bash 4+) |
| npm | Toute version | Optionnel |
| coreutils | Standard | `find`, `grep`, `ls` |

### Pour le workflow GitHub Actions

| Prérequis | Notes |
| --- | --- |
| Compte GitHub | Avec accès aux repos à scanner |
| Secret `PERSONAL_PAT` | Token GitHub avec scopes `repo` et `read:org` |
| `jq` | Installé automatiquement sur `ubuntu-latest` |

---

## Installation

### Cloner le repo

```bash
# Linux / macOS / WSL
git clone https://github.com/valorisa/audit-bitwarden-shai-hulud.git
cd audit-bitwarden-shai-hulud
```

```powershell
# PowerShell — Windows 11
git clone https://github.com/valorisa/audit-bitwarden-shai-hulud.git
Set-Location -Path "C:\Users\bbrod\Projets\audit-bitwarden-shai-hulud"
```

### Configurer le workflow GitHub Actions

1. Forker ou cloner ce repo dans votre organisation / compte GitHub.
2. Créer un Personal Access Token (PAT) avec les scopes suivants :
   - `repo` (accès lecture sur les repos privés)
   - `read:org` (si vous scannez des repos d'organisation)
3. Ajouter le secret dans votre repo GitHub :
   - `Settings` → `Secrets and variables` → `Actions` → `New repository secret`
   - Nom : `PERSONAL_PAT`
   - Valeur : votre token

---

## Utilisation

### Script PowerShell — Windows 11

Ouvrir une session PowerShell 7.6.1 et exécuter :

```powershell
# Scan du dossier courant
.\Audit-BitwardenShaiHulud.ps1

# Scan d'un dossier spécifique
.\Audit-BitwardenShaiHulud.ps1 -ScanPath "C:\Users\bbrod\Projets"

# Scan avec export du rapport JSON
.\Audit-BitwardenShaiHulud.ps1 `
    -ScanPath "C:\Users\bbrod\Projets" `
    -ReportPath "C:\Users\bbrod\Desktop\rapport-bitwarden.json"
```

Si la politique d'exécution bloque le script, l'autoriser pour la session :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Audit-BitwardenShaiHulud.ps1 -ScanPath "C:\Users\bbrod\Projets"
```

#### Exemple de sortie PowerShell

```text
╔══════════════════════════════════════════════════════════╗
║  Audit Bitwarden CLI 2026.4.0 / Shai-Hulud              ║
╚══════════════════════════════════════════════════════════╝
  Date    : 2026-04-24 10:32:17
  Machine : DESKTOP-BBROD\bbrod
  Dossier : C:\Users\bbrod\Projets

=== 1. Vérification de npm ===
  [INFO]   npm trouvé : C:\Program Files\nodejs\npm.cmd

=== 2. Package @bitwarden/cli@2026.4.0 (npm global) ===
  [OK]     Pas trouvé dans npm global

=== 3. Références à 2026.4.0 dans les fichiers de lock ===
  [OK]     Aucune référence à 2026.4.0 dans les fichiers de lock

=== 4. Fichier malware (bw1.js / bw_setup.js) ===
  [OK]     Aucun fichier bw1.js / bw_setup.js détecté

=== 5. Cache npm ===
  [OK]     Aucune trace dans le cache npm

=== 6. Traces du domaine C2 (audit.checkmarx.cx) ===
  [OK]     Aucune trace du domaine C2 détectée

=== 7. Backdoor dans les profils PowerShell ===
  [OK]     Aucune backdoor dans les profils PowerShell

=== 8. Workflows GitHub Actions suspects ===
  [OK]     Aucun workflow GitHub Actions suspect dans C:\Users\bbrod\Projets

=== 9. Rappel — dépôts GitHub suspects (noms Dune) ===
  [INFO]   Le malware crée des dépôts publics avec des noms issus de Dune :
  [INFO]     atreides, fremen, sardaukar, harkonnen
  [INFO]   Vérifiez manuellement : https://github.com/valorisa?tab=repositories

╔══════════════════════════════════════════════════════════╗
║  RÉSUMÉ                                                  ║
╚══════════════════════════════════════════════════════════╝
  Durée    : 4.3s
  Alertes  : 0
  Avertiss.: 0

  [OK] Aucune alerte — machine a priori saine.
```

### Script Bash — Linux et macOS

```bash
# Rendre le script exécutable
chmod +x audit-bitwarden-shai-hulud.sh

# Scan du dossier courant
./audit-bitwarden-shai-hulud.sh

# Scan depuis n'importe quel chemin
bash /chemin/vers/audit-bitwarden-shai-hulud.sh
```

#### Exemple de sortie Bash

```text
╔══════════════════════════════════════════════════════════╗
║  Audit Bitwarden CLI 2026.4.0 / Shai-Hulud               ║
╚══════════════════════════════════════════════════════════╝
  Date : 2026-04-24 10:32:17
  User : bbrod@hostname

=== 1. Package @bitwarden/cli@2026.4.0 (npm global) ===
  ✓ Pas trouvé dans npm global

=== 2. Package @bitwarden/cli@2026.4.0 (projets locaux) ===
  ✓ Pas trouvé dans les fichiers de lock locaux
  [...]

=== RÉSUMÉ ===
  ✓ Aucune alerte — machine a priori saine.
```

### GitHub Actions — scan multi-repos

Le workflow se déclenche de deux façons :

- **Manuellement** via `workflow_dispatch` (avec choix du mode et dry-run)
- **Automatiquement** chaque nuit à 3h UTC via `schedule`

Pour un déclenchement manuel :

1. Aller dans `Actions` → `Audit Bitwarden CLI 2026.4.0 (Shai‑Hulud)`
2. Cliquer sur `Run workflow`
3. Choisir le mode (`list`, `topic` ou `all`)
4. Activer `dry_run` si vous souhaitez uniquement voir les repos ciblés

---

## Configuration avancée

### Modes de sélection des repos

Le workflow propose trois modes, configurables via les variables d'environnement
en tête du fichier `.github/workflows/audit-bitwarden-2026.4.0.yml`.

#### Mode `list` — liste explicite

Modifier la variable `REPO_LIST` dans le workflow :

```yaml
env:
  REPO_LIST: "valorisa/mon-api,valorisa/mon-frontend,valorisa/infra-scripts"
```

Utiliser ce mode pour cibler précisément les repos qui utilisent ou ont pu
utiliser le Bitwarden CLI dans leurs pipelines.

#### Mode `topic` — topic GitHub (recommandé)

Modifier la variable `REPO_TOPIC` :

```yaml
env:
  REPO_TOPIC: "production"
```

Les topics s'appliquent aux repos depuis `Settings` → `Topics` sur GitHub.
Il est conseillé de taguer vos repos critiques (ceux avec des pipelines CI/CD,
des secrets cloud, etc.) avec un topic dédié, par exemple `cicd` ou
`production`.

Ce mode est le plus pratique pour des parcs de repos importants car il ne
nécessite pas de maintenir une liste manuelle.

#### Mode `all` — tous les repos (à utiliser avec précaution)

Ce mode scanne tous les repos accessibles par le PAT, dans la limite de
`MAX_REPOS` (50 par défaut) :

```yaml
env:
  MAX_REPOS: "50"
```

Augmenter cette limite si votre parc dépasse 50 repos. À noter que chaque
clone et scan consomme des minutes GitHub Actions.

### Export du rapport JSON

Le script PowerShell supporte l'export d'un rapport structuré en JSON :

```powershell
.\Audit-BitwardenShaiHulud.ps1 `
    -ScanPath "C:\Users\bbrod\Projets" `
    -ReportPath "C:\Users\bbrod\Desktop\rapport-bitwarden-2026-04-24.json"
```

Le rapport JSON produit a la structure suivante :

```json
{
  "GeneratedAt": "2026-04-24T10:32:17.000Z",
  "Machine": "DESKTOP-BBROD\\bbrod",
  "ScanPath": "C:\\Users\\bbrod\\Projets",
  "AlertCount": 0,
  "WarnCount": 0,
  "Findings": []
}
```

### Dry-run

Le workflow GitHub Actions intègre un mode dry-run : il liste les repos qui
seraient scannés sans effectuer aucun clone ni analyse. Utile pour vérifier
votre configuration avant le premier vrai run.

Activer le dry-run lors d'un déclenchement manuel via l'interface GitHub
(`Run workflow` → cocher `Dry-run`).

---

## Ce que détectent les scripts

### Vecteurs d'attaque vérifiés

| Vecteur | PowerShell | Bash | GitHub Actions |
| --- | :---: | :---: | :---: |
| Package npm global `@bitwarden/cli@2026.4.0` | ✅ | ✅ | ✅ |
| Référence dans `package.json` / lock files | ✅ | ✅ | ✅ |
| Fichier malware `bw1.js` / `bw_setup.js` | ✅ | ✅ | ✅ |
| Cache npm local | ✅ | ✅ | — |
| Domaine C2 `audit.checkmarx.cx` dans les logs | ✅ | ✅ | — |
| Domaine C2 dans l'historique shell / PSReadLine | ✅ | ✅ | — |
| Fichier lock temporaire `/tmp/tmp.*.lock` | — | ✅ | — |
| Backdoor dans les profils shell / PowerShell | ✅ | ✅ | — |
| Workflows GitHub Actions compromis | ✅ | ✅ | ✅ |
| Événements Windows (Security + Application) | ✅ | — | — |

### Patterns Shai-Hulud recherchés

Les scripts recherchent les chaînes suivantes dans les fichiers de workflow,
profils shell, logs et historiques :

```text
audit\.checkmarx
Shai-Hulud
RunCredentialHarvester
LongLiveTheResistance
bw1\.js
bw_setup\.js
```

---

## Actions à mener si compromis

Si l'un des scripts détecte une alerte, suivre dans l'ordre :

### Étape 1 — Désinstaller le package compromis

```bash
npm uninstall -g @bitwarden/cli
npm cache clean --force
```

### Étape 2 — Révoquer tous les tokens potentiellement exfiltrés

- **GitHub** : `Settings` → `Developer settings` → `Personal access tokens` →
  révoquer tous les tokens actifs et en regénérer de nouveaux
- **npm** : `npm token revoke <token-id>` ou via le portail npmjs.com
- **AWS** : console IAM → désactiver et supprimer les access keys compromises
- **Azure** : portail Azure → révoquer les tokens des service principals concernés

### Étape 3 — Régénérer les clés SSH

```bash
# Générer une nouvelle paire de clés
ssh-keygen -t ed25519 -C "votre@email.com" -f ~/.ssh/id_ed25519_new

# Supprimer l'ancienne clé de GitHub
# GitHub → Settings → SSH and GPG keys → Delete
# Puis ajouter la nouvelle clé publique
cat ~/.ssh/id_ed25519_new.pub
```

### Étape 4 — Auditer et nettoyer les workflows GitHub

Vérifier les workflows modifiés récemment dans vos repos :

```bash
# Lister les commits récents sur .github/workflows/
git log --oneline --since="2026-04-22" -- .github/workflows/
```

Supprimer tout workflow contenant les patterns Shai-Hulud listés ci-dessus.

### Étape 5 — Vérifier les dépôts GitHub créés par le malware

Le malware crée des dépôts publics avec des noms issus de *Dune*. Vérifier
manuellement sur votre compte : <https://github.com/valorisa?tab=repositories>

Noms suspects à rechercher : `atreides`, `fremen`, `sardaukar`, `harkonnen`.

### Étape 6 — Nettoyer les profils shell / PowerShell

Si une backdoor est détectée dans un profil, l'ouvrir et supprimer les lignes
suspectes :

```powershell
# PowerShell — ouvrir le profil concerné
notepad $PROFILE
# ou avec VS Code
code $PROFILE
```

```bash
# Bash
nano ~/.bashrc
# ou
nano ~/.zshrc
```

---

## FAQ

### Le script indique qu'npm n'est pas trouvé — est-ce grave ?

Non. Les vérifications npm sont simplement ignorées. Si vous n'utilisez pas npm
sur la machine scannée, il n'y a pas de risque lié à ce vecteur.

### J'utilise Bitwarden au quotidien — dois-je désinstaller l'application ?

Non. L'incident ne concerne **que** le package CLI npm
`@bitwarden/cli@2026.4.0`.
Les applications desktop, mobiles, extensions navigateur et coffres utilisateur
ne sont pas affectés.

### Le workflow GitHub Actions va-t-il cloner mes repos sur mon PC ?

Non. Le workflow s'exécute entièrement sur un **runner GitHub** (ubuntu-latest).
Les clones sont créés dans l'espace temporaire du runner, qui est détruit à la
fin du job. Votre poste Windows 11 n'est pas impliqué.

### Que signifie le scope `repo` du PAT pour le workflow ?

Le scope `repo` permet au workflow de lire le contenu de vos repos privés
(code source, workflows). Il n'accorde aucun droit d'écriture dans cette
configuration. Pour plus de sécurité, vous pouvez créer un PAT à durée
limitée (30 jours) et le renouveler régulièrement.

### Le script PowerShell échoue avec une erreur d'exécution de script

La politique d'exécution de PowerShell bloque peut-être les scripts non signés.
Deux options :

```powershell
# Option 1 : autoriser pour la session uniquement (recommandé)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Audit-BitwardenShaiHulud.ps1

# Option 2 : débloquer le fichier téléchargé
Unblock-File -Path .\Audit-BitwardenShaiHulud.ps1
.\Audit-BitwardenShaiHulud.ps1
```

### Puis-je lancer le script PowerShell depuis WSL ?

Oui, avec PowerShell installé dans WSL :

```bash
pwsh -File ./Audit-BitwardenShaiHulud.ps1 -ScanPath "/mnt/c/Users/bbrod/Projets"
```

---

## Contribuer

Les contributions sont les bienvenues. Pour proposer une amélioration :

1. Forker le repo
2. Créer une branche : `git checkout -b feat/ma-contribution`
3. Commiter vos changements : `git commit -m "feat: description"`
4. Pousser : `git push origin feat/ma-contribution`
5. Ouvrir une Pull Request

Merci de vous assurer que vos scripts Bash passent `shellcheck` et que vos
scripts PowerShell ne génèrent pas d'erreurs avec `PSScriptAnalyzer`.

---

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](LICENSE)
pour les détails.

---

> Réalisé à la suite de l'incident Shai-Hulud du 22 avril 2026.
> Pour toute question, ouvrir une [issue](https://github.com/valorisa/audit-bitwarden-shai-hulud/issues).
