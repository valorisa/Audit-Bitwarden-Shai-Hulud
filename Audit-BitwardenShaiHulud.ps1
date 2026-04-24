#Requires -Version 5.1
<#
.SYNOPSIS
    Audit local — compromission @bitwarden/cli@2026.4.0 (Shai-Hulud: The Third Coming)
.DESCRIPTION
    Vérifie la présence du package npm compromis, des fichiers malware, des traces
    d'exfiltration vers le domaine C2, et des backdoors dans les profils PowerShell.
    Optimisé pour Windows 11 (PowerShell 5.1+ / 7+), sans dépendances externes.
.EXAMPLE
    .\Audit-BitwardenShaiHulud.ps1
    .\Audit-BitwardenShaiHulud.ps1 -ScanPath "C:\projects" -Verbose
#>

[CmdletBinding()]
param(
    # Dossier racine pour la recherche de fichiers de lock et node_modules
    [string]$ScanPath = (Get-Location).Path,
    # Exporte un rapport JSON si ce paramètre est fourni
    [string]$ReportPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ── Helpers couleurs ──────────────────────────────────────────────────────────
function Write-Banner([string]$Text) {
    Write-Host "`n=== $Text ===" -ForegroundColor Cyan
}
function Write-Ok([string]$Text) {
    Write-Host "  [OK]     $Text" -ForegroundColor Green
}
function Write-Warn([string]$Text) {
    Write-Host "  [WARN]   $Text" -ForegroundColor Yellow
    $script:Findings += @{ Level = "WARN"; Message = $Text }
}
function Write-Alert([string]$Text) {
    Write-Host "  [ALERTE] $Text" -ForegroundColor Red
    $script:Findings += @{ Level = "ALERT"; Message = $Text }
}
function Write-Info([string]$Text) {
    Write-Host "  [INFO]   $Text" -ForegroundColor Gray
}

# ── Init ──────────────────────────────────────────────────────────────────────
$script:Findings = @()
$StartTime = Get-Date

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Audit Bitwarden CLI 2026.4.0 / Shai-Hulud              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Date    : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "  Machine : $env:COMPUTERNAME\$env:USERNAME"
Write-Host "  Dossier : $ScanPath"

# ── 1. npm disponible ? ───────────────────────────────────────────────────────
Write-Banner "1. Vérification de npm"
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    Write-Warn "npm introuvable dans le PATH — les vérifications npm seront ignorées."
    $npmAvailable = $false
} else {
    Write-Info "npm trouvé : $($npmCmd.Source)"
    $npmAvailable = $true
}

# ── 2. Package npm global ─────────────────────────────────────────────────────
Write-Banner "2. Package @bitwarden/cli@2026.4.0 (npm global)"
if ($npmAvailable) {
    $npmGlobal = npm list -g --depth 0 2>$null
    if ($npmGlobal -match "@bitwarden/cli.*2026\.4\.0") {
        Write-Alert "@bitwarden/cli@2026.4.0 installé GLOBALEMENT — désinstaller immédiatement !"
        Write-Info  "  Commande : npm uninstall -g @bitwarden/cli"
    } else {
        Write-Ok "Pas trouvé dans npm global"
    }
} else {
    Write-Info "Ignoré (npm non disponible)"
}

# ── 3. Fichiers de lock dans les projets locaux ───────────────────────────────
Write-Banner "3. Références à 2026.4.0 dans les fichiers de lock"
$lockFiles = @("package-lock.json", "yarn.lock", "package.json")
$lockPattern = "bitwarden.*2026\.4\.0|2026\.4\.0.*bitwarden"

$lockHits = Get-ChildItem -Path $ScanPath -Recurse -Include $lockFiles `
    -Exclude "node_modules" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" } |
    Select-String -Pattern $lockPattern -List

if ($lockHits) {
    foreach ($hit in $lockHits) {
        Write-Alert "Version compromise trouvée dans : $($hit.Path)"
    }
} else {
    Write-Ok "Aucune référence à 2026.4.0 dans les fichiers de lock"
}

# ── 4. Fichier malware bw1.js / bw_setup.js ──────────────────────────────────
Write-Banner "4. Fichier malware (bw1.js / bw_setup.js)"
$malwareFiles = Get-ChildItem -Path $ScanPath -Recurse `
    -Include "bw1.js", "bw_setup.js" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\node_modules\\" }

if ($malwareFiles) {
    foreach ($f in $malwareFiles) {
        Write-Alert "Fichier malware détecté : $($f.FullName)"
    }
} else {
    Write-Ok "Aucun fichier bw1.js / bw_setup.js détecté"
}

# ── 5. Cache npm ──────────────────────────────────────────────────────────────
Write-Banner "5. Cache npm"
if ($npmAvailable) {
    $cacheDir = npm config get cache 2>$null
    if (-not $cacheDir) { $cacheDir = "$env:APPDATA\npm-cache" }

    $cacheHit = Get-ChildItem -Path $cacheDir -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "bitwarden.*cli.*2026\.4\.0" }

    if ($cacheHit) {
        Write-Warn "Version compromise trouvée dans le cache npm : $cacheDir"
        Write-Info "  Pour purger : npm cache clean --force"
    } else {
        Write-Ok "Aucune trace dans le cache npm"
    }
} else {
    Write-Info "Ignoré (npm non disponible)"
}

# ── 6. Domaine C2 dans les fichiers de log et l'historique ───────────────────
Write-Banner "6. Traces du domaine C2 (audit.checkmarx.cx)"
$c2Pattern = "audit\.checkmarx"
$c2Found   = $false

# Historique PowerShell
$psHistoryPath = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
if (-not $psHistoryPath) {
    $psHistoryPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
}
if (Test-Path $psHistoryPath) {
    if (Select-String -Path $psHistoryPath -Pattern $c2Pattern -Quiet) {
        Write-Alert "Domaine C2 trouvé dans l'historique PowerShell : $psHistoryPath"
        $c2Found = $true
    }
}

# %TEMP%
$tempHits = Get-ChildItem -Path $env:TEMP -Recurse -ErrorAction SilentlyContinue |
    Select-String -Pattern $c2Pattern -Quiet
if ($tempHits) {
    Write-Alert "Domaine C2 trouvé dans %TEMP%"
    $c2Found = $true
}

# Logs d'événements Windows (Security + Application)
foreach ($log in @("Security", "Application")) {
    $events = Get-WinEvent -LogName $log -MaxEvents 1000 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match $c2Pattern }
    if ($events) {
        Write-Alert "Domaine C2 trouvé dans les événements Windows ($log) !"
        $c2Found = $true
    }
}

if (-not $c2Found) {
    Write-Ok "Aucune trace du domaine C2 détectée"
}

# ── 7. Backdoor dans les profils PowerShell ───────────────────────────────────
Write-Banner "7. Backdoor dans les profils PowerShell"
$backdoorPattern = "audit\.checkmarx|Shai-Hulud|RunCredentialHarvester|LongLiveTheResistance"
$profileFiles = @(
    $PROFILE.CurrentUserCurrentHost,
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.AllUsersCurrentHost,
    $PROFILE.AllUsersAllHosts
)

$shellClean = $true
foreach ($pf in $profileFiles) {
    if ($pf -and (Test-Path $pf)) {
        if (Select-String -Path $pf -Pattern $backdoorPattern -Quiet) {
            Write-Alert "Backdoor détectée dans le profil PowerShell : $pf"
            $shellClean = $false
        }
    }
}
if ($shellClean) { Write-Ok "Aucune backdoor dans les profils PowerShell" }

# ── 8. Workflows GitHub Actions suspects ──────────────────────────────────────
Write-Banner "8. Workflows GitHub Actions suspects"
$ghaPattern = "audit\.checkmarx|Shai-Hulud|RunCredentialHarvester|LongLiveTheResistance|bw1\.js"
$ghaDir = Join-Path $ScanPath ".github\workflows"
$ghaClean = $true

if (Test-Path $ghaDir) {
    $ghaHits = Get-ChildItem -Path $ghaDir -Include "*.yml", "*.yaml" -Recurse |
        Select-String -Pattern $ghaPattern -List

    foreach ($hit in $ghaHits) {
        Write-Alert "Workflow suspect : $($hit.Path)"
        $ghaClean = $false
    }
}
if ($ghaClean) { Write-Ok "Aucun workflow GitHub Actions suspect dans $ScanPath" }

# ── 9. Vérifier les dépôts créés par le malware sur GitHub (noms Dune) ────────
Write-Banner "9. Rappel — dépôts GitHub suspects (noms Dune)"
Write-Info "Le malware crée des dépôts publics avec des noms issus de Dune :"
Write-Info "  atreides, fremen, sardaukar, harkonnen"
Write-Info "Vérifiez manuellement : https://github.com/<votre-compte>?tab=repositories"

# ── Résumé ────────────────────────────────────────────────────────────────────
$elapsed = (Get-Date) - $StartTime
$alerts  = @($script:Findings | Where-Object { $_.Level -eq "ALERT" })
$warns   = @($script:Findings | Where-Object { $_.Level -eq "WARN" })

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RÉSUMÉ                                                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Durée    : $([math]::Round($elapsed.TotalSeconds, 1))s"
Write-Host "  Alertes  : $($alerts.Count)" -ForegroundColor $(if ($alerts.Count -gt 0) { "Red" } else { "Green" })
Write-Host "  Avertiss.: $($warns.Count)"  -ForegroundColor $(if ($warns.Count  -gt 0) { "Yellow" } else { "Green" })

if ($script:Findings.Count -eq 0) {
    Write-Host "`n  [OK] Aucune alerte — machine a priori saine.`n" -ForegroundColor Green
} else {
    Write-Host "`n  Actions immédiates recommandées :" -ForegroundColor Red
    Write-Host "  1. npm uninstall -g @bitwarden/cli       (si présent)"
    Write-Host "  2. npm cache clean --force"
    Write-Host "  3. Révoquer : tokens GitHub, npm, AWS, Azure"
    Write-Host "  4. Régénérer vos clés SSH"
    Write-Host "  5. Vérifier vos profils PowerShell"
    Write-Host "  6. Auditer vos workflows GitHub Actions"
    Write-Host "  7. Vérifier les dépôts GitHub (noms Dune : atreides, fremen...)"
    Write-Host ""
}

# ── Export JSON optionnel ─────────────────────────────────────────────────────
if ($ReportPath) {
    $report = @{
        GeneratedAt = $StartTime.ToString("o")
        Machine     = "$env:COMPUTERNAME\$env:USERNAME"
        ScanPath    = $ScanPath
        AlertCount  = $alerts.Count
        WarnCount   = $warns.Count
        Findings    = $script:Findings
    }
    $report | ConvertTo-Json -Depth 5 | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Info "Rapport exporté : $ReportPath"
}
