#!/bin/bash
# =============================================================================
#  Linky – Uninstaller
#  Verwendung:
#    curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/uninstall.sh | bash
# =============================================================================

set -euo pipefail

APP_NAME="Linky"
INSTALL_DIR="/Applications"

BOLD=$'\033[1m'
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
BLU=$'\033[0;34m'
DIM=$'\033[2m'
NC=$'\033[0m'

step() { echo -e "\n${BLU}${BOLD}▶ $*${NC}"; }
ok()   { echo -e "  ${GRN}✔${NC}  $*"; }
skip() { echo -e "  ${DIM}–${NC}  $* (nicht gefunden)"; }

echo ""
echo -e "${RED}${BOLD}  Linky – Deinstallation${NC}"
echo ""

# ── 1. App beenden ────────────────────────────────────────────────────────
step "App beenden"
if pkill -x Linky 2>/dev/null; then
    ok "Linky beendet"
    sleep 1
else
    skip "Linky lief nicht"
fi

# ── 2. App entfernen ──────────────────────────────────────────────────────
step "App entfernen"
if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
    rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
    ok "Linky.app entfernt"
else
    skip "${INSTALL_DIR}/${APP_NAME}.app"
fi

# ── 3. Alle Workflows aus ~/Library/Services/ entfernen ───────────────────
step "Quick Actions entfernen"
SERVICES_DIR=~/Library/Services
REMOVED=0
for WF in \
    "SMB-Link kopieren.workflow" \
    "SMB-Link öffnen.workflow" \
    "Linky SMB-Link öffnen.workflow"; do
    if [[ -d "$SERVICES_DIR/$WF" ]]; then
        rm -rf "$SERVICES_DIR/$WF"
        ok "Entfernt: $WF"
        REMOVED=1
    else
        skip "$WF"
    fi
done

# ── 4. pbs.plist Einträge bereinigen ──────────────────────────────────────
step "Services-Cache bereinigen"
PBS_PLIST=~/Library/Preferences/pbs.plist

if [[ -f "$PBS_PLIST" ]]; then
    # Alle Linky/SMB-Einträge aus NSServicesStatus entfernen
    KEYS=$(plutil -convert xml1 "$PBS_PLIST" -o - 2>/dev/null \
        | grep -o '"[^"]*SMB-Link[^"]*"\|"[^"]*Linky[^"]*"' \
        | tr -d '"' || true)

    if [[ -n "$KEYS" ]]; then
        while IFS= read -r KEY; do
            plutil -remove "NSServicesStatus.$KEY" "$PBS_PLIST" 2>/dev/null && \
                ok "Cache-Eintrag entfernt: $KEY" || true
        done <<< "$KEYS"
    else
        ok "Keine Linky-Eintraege im Services-Cache"
    fi
else
    skip "pbs.plist"
fi

# ── 5. Services-Datenbank neu aufbauen ────────────────────────────────────
step "Services-Datenbank aktualisieren"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
ok "pbs aktualisiert"

# ── 6. LaunchAgent entfernen ──────────────────────────────────────────────
step "Autostart entfernen"
LAUNCH_AGENT=~/Library/LaunchAgents/com.linky.autostart.plist
if [[ -f "$LAUNCH_AGENT" ]]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT"
    ok "LaunchAgent entfernt"
else
    skip "LaunchAgent"
fi

# ── 7. Einstellungen entfernen ────────────────────────────────────────────
step "Einstellungen entfernen"
if [[ -f ~/Library/Preferences/com.linky.app.plist ]]; then
    defaults delete com.linky.app 2>/dev/null || true
    ok "Einstellungen entfernt"
else
    skip "com.linky.app.plist"
fi

# ── 8. Finder neu starten ─────────────────────────────────────────────────
step "Finder neu starten"
killall Finder 2>/dev/null || true
sleep 2
ok "Finder neu gestartet"

# ── Fertig ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}${BOLD}  ✔ Linky vollständig deinstalliert!${NC}"
echo ""
echo -e "  ${DIM}Rechtsklick-Menu und Dienste sind jetzt sauber.${NC}"
echo -e "  ${DIM}Neu installieren:${NC}"
echo -e "  curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash"
echo ""
