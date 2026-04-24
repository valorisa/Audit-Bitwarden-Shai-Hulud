#!/usr/bin/env bash
# =============================================================================
# audit-bitwarden-shai-hulud.sh
# Audit local — compromission @bitwarden/cli@2026.4.0 (Shai-Hulud: The Third Coming)
# Vérifie : package npm, fichiers malware, traces d'exfiltration, backdoors shell
# =============================================================================

set -euo pipefail

# --- Couleurs ---
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

FOUND=0   # compteur d'alertes

banner() {
  echo -e "\n${BOLD}${CYAN}=== $* ===${RESET}"
}

ok()    { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $*"; FOUND=$((FOUND + 1)); }
alert() { echo -e "  ${RED}🚨 ALERTE${RESET} — $*"; FOUND=$((FOUND + 1)); }
info()  { echo -e "  ${CYAN}ℹ${RESET}  $*"; }

echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════╗"
echo    "║  Audit Bitwarden CLI 2026.4.0 / Shai-Hulud               ║"
echo -e "╚══════════════════════════════════════════════════════════╝${RESET}"
echo    "  Date : $(date '+%Y-%m-%d %H:%M:%S')"
echo    "  User : $(whoami)@$(hostname)"

# --- 1. Package npm global ---
banner "1. Package @bitwarden/cli@2026.4.0 (npm global)"
if npm list -g --depth 0 2>/dev/null | grep -q "@bitwarden/cli.*2026\.4\.0"; then
  alert "@bitwarden/cli@2026.4.0 est installé GLOBALEMENT → désinstaller immédiatement !"
  info  "  Commande : npm uninstall -g @bitwarden/cli"
else
  ok "Pas trouvé dans npm global"
fi

# --- 2. Package npm local (dossier courant et sous-dossiers) ---
banner "2. Package @bitwarden/cli@2026.4.0 (projets locaux)"
mapfile -t lock_hits < <(
  find . \( -name "package-lock.json" -o -name "yarn.lock" -o -name "package.json" \) \
       -not -path "*/node_modules/*" \
       -exec grep -l "bitwarden.*2026\.4\.0\|2026\.4\.0.*bitwarden" {} \; 2>/dev/null
)
if [[ ${#lock_hits[@]} -gt 0 ]]; then
  for f in "${lock_hits[@]}"; do
    alert "Version compromise trouvée dans : $f"
  done
else
  ok "Pas trouvé dans les fichiers de lock locaux"
fi

# --- 3. Fichier malware bw1.js ---
banner "3. Fichier malware bw1.js / bw_setup.js"
mapfile -t bw1_hits < <(
  find . -type d -name "node_modules" -prune -o \
       \( -name "bw1.js" -o -name "bw_setup.js" \) -print 2>/dev/null
)
if [[ ${#bw1_hits[@]} -gt 0 ]]; then
  for f in "${bw1_hits[@]}"; do
    alert "Fichier malware détecté : $f"
  done
else
  ok "Aucun fichier bw1.js / bw_setup.js trouvé"
fi

# --- 4. Cache npm ---
banner "4. Cache npm"
npm_cache_dir=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
if find "$npm_cache_dir" -path "*bitwarden*cli*2026.4.0*" 2>/dev/null | grep -q .; then
  warn "Version compromise trouvée dans le cache npm : $npm_cache_dir"
  info "  Pour purger : npm cache clean --force"
else
  ok "Pas de trace dans le cache npm"
fi

# --- 5. Domaine C2 Checkmarx ---
banner "5. Traces du domaine C2 (audit.checkmarx.cx)"
C2_PATTERN="audit\.checkmarx"
c2_found=0

# Historique shell
for hist_file in ~/.bash_history ~/.zsh_history ~/.history; do
  if [[ -f "$hist_file" ]] && grep -q "$C2_PATTERN" "$hist_file" 2>/dev/null; then
    alert "Domaine C2 trouvé dans $hist_file"
    c2_found=1
  fi
done

# /tmp et logs système
if grep -rq "$C2_PATTERN" /tmp 2>/dev/null; then
  alert "Domaine C2 trouvé dans /tmp"
  c2_found=1
fi
if grep -rq "$C2_PATTERN" /var/log 2>/dev/null; then
  warn "Domaine C2 trouvé dans /var/log (vérifier manuellement)"
  c2_found=1
fi

[[ $c2_found -eq 0 ]] && ok "Aucune trace du domaine C2 détectée"

# --- 6. Lock file temporaire du malware ---
banner "6. Fichier lock temporaire du malware (/tmp/tmp.*.lock)"
if ls /tmp/tmp.*.lock 2>/dev/null | grep -q .; then
  alert "Fichier(s) suspect(s) trouvé(s) :"
  ls -la /tmp/tmp.*.lock 2>/dev/null
else
  ok "Aucun fichier /tmp/tmp.*.lock"
fi

# --- 7. Backdoor dans les fichiers de profil shell ---
banner "7. Backdoor dans les profils shell"
BACKDOOR_PATTERN="audit\.checkmarx\|Shai-Hulud\|RunCredentialHarvester\|LongLiveTheResistance"
shell_infected=0

for rc_file in ~/.bashrc ~/.zshrc ~/.profile ~/.bash_profile ~/.bash_login; do
  if [[ -f "$rc_file" ]] && grep -Eq "$BACKDOOR_PATTERN" "$rc_file" 2>/dev/null; then
    alert "Backdoor détectée dans $rc_file !"
    shell_infected=1
  fi
done

[[ $shell_infected -eq 0 ]] && ok "Aucune backdoor dans les profils shell"

# --- 8. Workflows GitHub suspects dans le dossier courant ---
banner "8. Workflows GitHub Actions suspects (.github/workflows)"
GHA_PATTERN="audit\.checkmarx\|Shai-Hulud\|RunCredentialHarvester\|LongLiveTheResistance\|bw1\.js"
gha_found=0

if [[ -d ".github/workflows" ]]; then
  mapfile -t gha_hits < <(
    find .github/workflows -type f \( -name "*.yml" -o -name "*.yaml" \) \
         -exec grep -lE "$GHA_PATTERN" {} \; 2>/dev/null
  )
  if [[ ${#gha_hits[@]} -gt 0 ]]; then
    for f in "${gha_hits[@]}"; do
      alert "Workflow suspect détecté : $f"
    done
    gha_found=1
  fi
fi

[[ $gha_found -eq 0 ]] && ok "Aucun workflow GitHub suspect dans ce dossier"

# --- Résumé final ---
echo -e "\n${BOLD}╔══════════════════════════════════════════════════════════╗"
echo    "║  RÉSUMÉ                                                  ║"
echo -e "╚══════════════════════════════════════════════════════════╝${RESET}"

if [[ $FOUND -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}✓ Aucune alerte détectée — machine a priori saine.${RESET}"
else
  echo -e "  ${RED}${BOLD}🚨 $FOUND alerte(s) détectée(s) !${RESET}"
  echo -e "\n  ${BOLD}Actions immédiates :${RESET}"
  echo    "  1. npm uninstall -g @bitwarden/cli  (si installé)"
  echo    "  2. npm cache clean --force"
  echo    "  3. Révoquer : tokens GitHub, npm, AWS, Azure"
  echo    "  4. Régénérer vos clés SSH"
  echo    "  5. Vérifier et nettoyer vos profils shell"
  echo    "  6. Auditer vos workflows GitHub Actions"
fi

echo ""
