#!/bin/bash
# =============================================================================
#  Linky – Linux Deinstaller
# =============================================================================

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"

BOLD=$'\033[1m'
GRN=$'\033[0;32m'
BLU=$'\033[0;34m'
NC=$'\033[0m'

ok() { echo -e "  ${GRN}✔${NC}  $*"; }

echo ""
echo -e "${BLU}${BOLD}  Linky – Deinstallation${NC}"
echo ""

# Daemon beenden
pkill -f "$BIN_DIR/linky" 2>/dev/null && ok "Prozess beendet" || true

# Dateien entfernen
rm -f "$BIN_DIR/linky"                      && ok "Skript entfernt"
rm -f "$DESKTOP_DIR/linky.desktop"          && ok "Desktop-Eintrag entfernt"
rm -f "$AUTOSTART_DIR/linky.desktop"        && ok "Autostart entfernt"

# Protokoll-Registrierung zurücksetzen
if command -v xdg-mime &>/dev/null; then
    xdg-mime default "" x-scheme-handler/smb 2>/dev/null || true
fi
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo -e "${GRN}${BOLD}  ✔ Linky wurde vollständig entfernt.${NC}"
echo ""
