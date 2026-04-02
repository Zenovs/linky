#!/bin/bash
# =============================================================================
#  Linky – macOS Installer
#  Verwendung:
#    curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
# =============================================================================

set -euo pipefail

GITHUB_REPO="Zenovs/linky"
APP_NAME="Linky"
INSTALL_DIR="/Applications"
MIN_MACOS=12

# ── Farben ────────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[1;33m'
BLU=$'\033[0;34m'
DIM=$'\033[2m'
NC=$'\033[0m'

step()    { echo -e "\n${BLU}${BOLD}▶ $*${NC}"; }
ok()      { echo -e "  ${GRN}✔${NC}  $*"; }
warn()    { echo -e "  ${YLW}⚠${NC}  $*"; }
die()     { echo -e "\n  ${RED}✖  $*${NC}\n"; exit 1; }

# ── Spinner ───────────────────────────────────────────────────────────────────
SPIN_PID=""
spin_start() {
    local msg="$1"
    ( local f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
      while true; do
          printf "\r  ${BLU}${f:$i:1}${NC}  %s" "$msg"
          i=$(( (i+1) % 10 )); sleep 0.08
      done ) &
    SPIN_PID=$!
}
spin_stop() {
    [[ -n "$SPIN_PID" ]] && kill "$SPIN_PID" 2>/dev/null; SPIN_PID=""
    printf "\r\033[K"
}
trap 'spin_stop' EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLU}${BOLD}"
echo "  ██╗     ██╗███╗   ██╗██╗  ██╗██╗   ██╗"
echo "  ██║     ██║████╗  ██║██║ ██╔╝╚██╗ ██╔╝"
echo "  ██║     ██║██╔██╗ ██║█████╔╝  ╚████╔╝ "
echo "  ██║     ██║██║╚██╗██║██╔═██╗   ╚██╔╝  "
echo "  ███████╗██║██║ ╚████║██║  ██╗   ██║   "
echo "  ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝  "
echo -e "${NC}"
echo -e "  ${DIM}SMB-Link Handler für macOS${NC}"
echo ""

# ── 1. Systemcheck ─────────────────────────────────────────────────────────
step "Systemvoraussetzungen prüfen"

[[ "$(uname)" == "Darwin" ]] || die "Linky läuft nur auf macOS."

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[[ "$MACOS_MAJOR" -ge "$MIN_MACOS" ]] \
    || die "macOS ${MIN_MACOS}+ erforderlich (gefunden: $(sw_vers -productVersion))."

ok "macOS $(sw_vers -productVersion)"
ok "Architektur: $(uname -m)"

# ── 2. Neueste Version ermitteln ───────────────────────────────────────────
step "Neueste Version ermitteln"

spin_start "GitHub API abfragen..."
API=$(curl -fsSL --max-time 10 \
    "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) \
    || { spin_stop; die "GitHub API nicht erreichbar. Internetverbindung prüfen."; }
spin_stop

VERSION=$(echo "$API" | grep '"tag_name"' \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
DMG_URL=$(echo "$API" | grep '"browser_download_url"' \
    | grep '\.dmg"' \
    | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/' \
    | head -1)

[[ -n "$VERSION" ]] || die "Keine Version auf GitHub gefunden."
[[ -n "$DMG_URL" ]] || die "Kein DMG für ${VERSION} gefunden.\nBitte manuell von https://github.com/${GITHUB_REPO}/releases herunterladen."

ok "Version ${VERSION} gefunden"

# Bereits installiert?
INSTALLED_VERSION=""
if [[ -f "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info.plist" ]]; then
    INSTALLED_VERSION=$(defaults read \
        "${INSTALL_DIR}/${APP_NAME}.app/Contents/Info" \
        CFBundleShortVersionString 2>/dev/null || echo "")
fi

if [[ -n "$INSTALLED_VERSION" && "v${INSTALLED_VERSION}" == "$VERSION" ]]; then
    ok "Bereits aktuell (${INSTALLED_VERSION}) – überspringe Download"
    SKIP_DOWNLOAD=1
else
    SKIP_DOWNLOAD=0
fi

# ── 3. DMG herunterladen ────────────────────────────────────────────────────
TMP_DMG=$(mktemp /tmp/Linky-XXXXXX.dmg)
TMP_MNT=$(mktemp -d /tmp/linky-mnt-XXXXXX)
cleanup() {
    spin_stop
    hdiutil detach "$TMP_MNT" -quiet 2>/dev/null || true
    rm -f "$TMP_DMG"
    rmdir "$TMP_MNT" 2>/dev/null || true
}
trap cleanup EXIT

if [[ "$SKIP_DOWNLOAD" -eq 1 ]]; then
    step "Installation überspringen"
    ok "Version ${INSTALLED_VERSION} bereits installiert – kein Download nötig"
else
    step "App herunterladen  ${DIM}(${VERSION})${NC}"
    echo ""
    curl -fL --progress-bar "$DMG_URL" -o "$TMP_DMG" \
        || die "Download fehlgeschlagen."
    echo ""
    ok "Download abgeschlossen"

    # ── 4. App installieren ──────────────────────────────────────────────
    step "App installieren"

    spin_start "Disk-Image einhängen..."
    hdiutil attach "$TMP_DMG" -mountpoint "$TMP_MNT" -quiet -nobrowse \
        || { spin_stop; die "DMG konnte nicht eingehängt werden."; }
    spin_stop
    ok "Image eingehängt"

    [[ -d "$TMP_MNT/${APP_NAME}.app" ]] \
        || die "${APP_NAME}.app nicht im DMG gefunden."

    spin_start "${APP_NAME}.app nach ${INSTALL_DIR} kopieren..."
    rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
    cp -R "$TMP_MNT/${APP_NAME}.app" "${INSTALL_DIR}/"
    spin_stop
    ok "App kopiert"

    # ── 5. Signierung & Quarantine ───────────────────────────────────────
    step "Sicherheitseinstellungen"

    spin_start "Ad-hoc Signatur anwenden..."
    codesign --force --deep --sign - "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true
    spin_stop
    ok "Signiert"

    spin_start "Quarantine-Flag entfernen..."
    xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true
    spin_stop
    ok "Quarantine entfernt"
fi

# ── 6. App starten ────────────────────────────────────────────────────────
step "Linky starten"

# Laufende Instanz beenden
pkill -x Linky 2>/dev/null || true
sleep 1

open "${INSTALL_DIR}/${APP_NAME}.app"
sleep 3

if pgrep -x Linky > /dev/null 2>&1; then
    ok "Linky läuft"
else
    warn "Linky konnte nicht automatisch gestartet werden."
    warn "Manuell starten: open /Applications/Linky.app"
fi

# ── Fertig ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}${BOLD}  ✔ Installation abgeschlossen!${NC}"
echo ""
echo -e "  ${DIM}App:${NC}        ${INSTALL_DIR}/${APP_NAME}.app"
echo -e "  ${DIM}Menüleiste:${NC} 🔗 Symbol oben rechts"
echo ""
echo -e "${YLW}${BOLD}  Zwei einmalige Schritte zum Abschluss:${NC}"
echo ""
echo -e "  ${BOLD}1. Bedienungshilfen erlauben${NC}"
echo -e "     macOS fragt automatisch nach der Berechtigung."
echo -e "     Systemeinstellungen > Datenschutz > Bedienungshilfen"
echo -e "     → Linky aktivieren  (noetig fuer Cmd+V Erkennung)"
echo ""
echo -e "  ${BOLD}2. Quick Actions aktivieren${NC}"
echo -e "     Ein Dialog erscheint gleich – auf ${BOLD}Einstellungen oeffnen${NC} klicken"
echo -e "     → alle drei Linky-Eintraege aktivieren"
echo -e "     (noetig fuer Rechtsklick-Menue im Finder & Browser)"
echo ""
