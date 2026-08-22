# 📋 Guide du Workflow d'Audit Bitwarden CLI

## 🎯 Objectif

Ce workflow automatise l'audit de sécurité de la supply chain pour détecter la présence de **@bitwarden/cli@2026.4.0** et d'autres indicateurs de compromission dans vos repositories.

---

## 🚨 Qu'est-ce que @bitwarden/cli@2026.4.0 ?

**@bitwarden/cli@2026.4.0** est une version malveillante du paquet npm officiel Bitwarden CLI qui contient du code malveillant.

### Risques potentiels

Si cette version est installée dans vos dépendances, le malware peut :

- ❌ Voler vos credentials (tokens GitHub, AWS, npm, etc.)
- ❌ Exfiltrer vos clés SSH privées
- ❌ Modifier vos repositories
- ❌ Injecter du code malveillant dans vos builds
- ❌ Prendre le contrôle de vos déploiements CI/CD
- ❌ Compromettre vos secrets d'organisation

### Fichiers scannés

Le workflow recherche cette version dans :
- `package.json`
- `package-lock.json`
- `yarn.lock`

---

## 🔧 Modes de Scan

Le workflow propose **3 modes de fonctionnement** :

### Mode 1 : **list** (Scan manuel)

**Description** : Scannez uniquement les repositories que vous spécifiez manuellement.

**Configuration** :
```yaml
env:
  REPO_LIST: "org/repo-a,org/repo-b,org/repo-c"
  REPO_TOPIC: ""
```

**Avantages** :
- ✅ Contrôle total
- ✅ Pas de limite de repos
- ✅ Idéal pour les repos critiques

**Exemple** :
```
REPO_LIST: "valorisa/backend,valorisa/api,valorisa/frontend"
```

---

### Mode 2 : **topic** (Scan par tag GitHub) — ⭐ RECOMMANDÉ

**Description** : Scannez les repositories avec un tag/topic GitHub spécifique.

**Configuration** :
```yaml
env:
  REPO_LIST: ""
  REPO_TOPIC: "production"
  MAX_REPOS: "50"
```

**Avantages** :
- ✅ Ciblé et efficace
- ✅ Maintien facile (ajoutez/retirez le tag sur GitHub)
- ✅ Scalable sans modification du workflow
- ✅ Limite de 50 repos par défaut

**Fonctionnement** :
1. Le workflow recherche tous vos repos avec le tag `production`
2. Scanne jusqu'à 50 d'entre eux (limite `MAX_REPOS`)
3. S'il y a plus de 50 repos, augmentez `MAX_REPOS`

**Exemple** :
```yaml
REPO_TOPIC: "production"      # Scannera tous les repos tagués "production"
REPO_TOPIC: "backend-services" # Ou tout autre tag personnalisé
```

---

### Mode 3 : **all** (Scan tous les repositories)

**Description** : Scannez TOUS vos repositories.

**Configuration** :
```yaml
env:
  REPO_LIST: ""
  REPO_TOPIC: ""
  MAX_REPOS: "50"
```

**Avantages** :
- ✅ Audit complet sans sélection

**⚠️ ATTENTION — LIMITATION CRITIQUE** :
- La limite `MAX_REPOS: "50"` s'applique
- Si vous avez 150 repos, seuls les 50 premiers seront scannés
- Les autres repos ne seront **PAS** auditès

**Cas de usage** :
- Audit initial complet
- Vérification générale

---

## 📊 Limites et Considérations

### Limite de 50 repositories

| Situation | Solution |
|-----------|----------|
| J'ai 150 repos, je veux tous les scanner | Augmentez `MAX_REPOS: "150"` ⚠️ Plus lent |
| J'ai 500 repos, audit complet | Utilisez mode "topic" avec plusieurs tags |
| Je veux scanner les repos critiques | Utilisez mode "list" avec les repos clés |
| Je veux un audit production quotidien | Utilisez mode "topic" avec tag "production" |

### Performance et coûts API

**Chaque exécution** :
- 1 appel API pour récupérer la liste des repos
- N appels pour cloner les repos (1 par repo)
- Consomme vos limites de rate-limiting GitHub API

**Recommandations** :
- ✅ Mode "topic" : Optimal (peu d'appels, ciblé)
- ⚠️ Mode "all" avec MAX_REPOS > 100 : Gourmand en API calls
- ✅ Mode "list" : Contrôlé et prévisible

---

## 🔄 Planification d'Exécution

### Schedule par défaut

```yaml
schedule:
  - cron: "0 3 * * *"  # Tous les jours à 3h du matin UTC
```

### Modifications

Pour changer l'heure, modifiez la cron expression :

```yaml
# Tous les lundis à 9h UTC
- cron: "0 9 * * 1"

# Chaque jour à minuit UTC
- cron: "0 0 * * *"

# Deux fois par jour (3h et 15h UTC)
- cron: "0 3,15 * * *"
```

---

## 🚀 Utilisation

### Exécution manuelle

1. Allez sur : **Actions** → **Audit Bitwarden CLI 2026.4.0**
2. Cliquez sur **Run workflow**
3. Choisissez le mode :
   - `list` — Scan manuel
   - `topic` — Scan par tag (défaut)
   - `all` — Scan tous les repos
4. Optionnel : Cochez **Dry-run** pour voir la liste sans scanner
5. Cliquez sur **Run workflow**

### Dry-run (aperçu sans scanner)

Activez l'option **Dry-run** pour :
- Voir la liste des repos qui seront scannés
- Valider votre configuration
- Sans exécuter les scans

---

## 📋 Vérifications effectuées

Le workflow vérifie 3 points de sécurité :

### 1️⃣ **@bitwarden/cli@2026.4.0 dans les dépendances**

Scanne `package.json`, `package-lock.json`, `yarn.lock` pour détecter :
```json
"@bitwarden/cli": "2026.4.0"
```

### 2️⃣ **Fichiers malware connus**

Recherche les fichiers injectés par le malware :
- `bw1.js`
- `bw_setup.js`

### 3️⃣ **Patterns de workflows suspects**

Analyse les workflows GitHub pour détecter :
- `audit.checkmarx`
- `Shai-Hulud` (nom du malware)
- `RunCredentialHarvester`
- `LongLiveTheResistance`
- Patterns d'injection de code

---

## 📊 Résultats et Rapports

### Rapport de synthèse

Après chaque scan, un rapport génère un tableau avec :

| Paramètre | Description |
|-----------|-------------|
| **Date** | Date/heure du scan |
| **Mode** | Mode utilisé (list/topic/all) |
| **Repos scannés** | Nombre de repos auditès |
| **Statut scan** | ✅ success ou ❌ failure |

### Résultats

- ✅ **Aucune alerte** : Vos repos sont sains
- 🚨 **Alertes détectées** : Action immédiate requise

### Action en cas d'alerte

Si une alerte est détectée :

1. **Supprimer @bitwarden/cli@2026.4.0** de tous les projets concernés
2. **Révoquer les tokens** : GitHub, npm, AWS, Azure, etc.
3. **Régénérer les clés SSH** privées
4. **Supprimer les workflows** suspects injectés
5. **Auditer les logs** d'accès pour détecter les activités malveillantes

---

## 🔐 Configuration Requise

### Secret obligatoire

**PERSONAL_PAT** : Personal Access Token GitHub

**Scopes requis** :
- ✅ `repo` — Accès complet aux repositories
- ✅ `read:org` — Lecture des informations d'organisation

**Comment créer** :

1. GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Nommez-le : `Audit-Bitwarden-Shai-Hulud-API`
3. Définissez les scopes : `repo`, `read:org`
4. Copiez le token
5. Allez sur Settings → Secrets and variables → Actions
6. Créez/mettez à jour le secret `PERSONAL_PAT`

---

## 📈 Bonnes Pratiques

### ✅ Pour un audit efficace

1. **Utilisez le mode "topic"** avec les tags GitHub
   - Taguez vos repos `production`, `backend-services`, etc.
   - Le workflow scannera automatiquement les repos pertinents

2. **Gardez MAX_REPOS raisonnable**
   - Commencez avec 50
   - Augmentez seulement si nécessaire

3. **Planifiez régulièrement**
   - Quotidien pour les repos production
   - Hebdomadaire pour les autres

4. **Testez en dry-run d'abord**
   - Validez votre configuration
   - Vérifiez la liste des repos avant le scan réel

5. **Maintenez vos secrets à jour**
   - Régénérez votre PERSONAL_PAT tous les 90 jours
   - Surveillez les expirations

---

## 🆘 Dépannage

### Erreur : HTTP 401 "Bad credentials"

**Cause** : Votre token PERSONAL_PAT est expiré ou invalide

**Solution** :
1. Génériez un nouveau token
2. Mettez à jour le secret `PERSONAL_PAT`
3. Relancez le workflow

### Erreur : "REPO_LIST est vide"

**Cause** : Mode "list" sélectionné sans repos configurés

**Solution** :
- Modifiez `REPO_LIST` avec vos repos
- Ou changez le mode en "topic" ou "all"

### Workflows s'exécutent trop lentement

**Cause** : MAX_REPOS trop élevé

**Solution** :
- Réduisez `MAX_REPOS` à 50
- Utilisez mode "topic" pour filtrer

---

## 📞 Support et Questions

Pour toute question sur ce workflow :

1. Consultez ce fichier
2. Vérifiez les logs d'exécution (Actions → Détails du run)
3. Inspectez le fichier `.github/workflows/audit-bitwarden-2026.4.0.yml`

---

## 📝 Historique des modifications

| Version | Date | Changements |
|---------|------|-------------|
| 1.0 | 2026-08-22 | Création initiale - Documentation complète |

---

**Dernière mise à jour** : 2026-08-22  
**Statut** : ✅ Opérationnel  
**Mode par défaut** : topic (production)
