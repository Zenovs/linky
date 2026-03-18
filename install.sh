#!/bin/bash
# =============================================================================
# Linky - Installer
# =============================================================================
# Verwendung:
#   curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
# =============================================================================

set -e

GITHUB_REPO="Zenovs/linky"
APP_NAME="Linky"
INSTALL_DIR="/Applications"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}▶${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✖ Fehler:${NC} $1"; exit 1; }
success() { echo -e "${GREEN}✔${NC} $1"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Linky Installer            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════╝${NC}"
echo ""

# Systemcheck
[[ "$(uname)" == "Darwin" ]] || error "Linky läuft nur auf macOS."

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[[ "$MACOS_MAJOR" -ge 12 ]] || error "macOS 12 (Monterey) oder neuer erforderlich."

# =============================================================================
# Python & PyObjC installieren (benötigt für die Python-Version von Linky)
# =============================================================================

# Python 3 suchen
PYTHON3=""
for p in /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3 python3; do
    if command -v "$p" &>/dev/null; then
        PYTHON3="$p"
        break
    fi
done

if [[ -z "$PYTHON3" ]]; then
    warn "Python 3 nicht gefunden. Versuche Installation via Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    # Nach Installation nochmal suchen
    for p in /usr/bin/python3 python3; do
        if command -v "$p" &>/dev/null; then
            PYTHON3="$p"
            break
        fi
    done
    [[ -n "$PYTHON3" ]] || error "Python 3 konnte nicht gefunden/installiert werden.\nBitte installieren: https://www.python.org/downloads/"
fi
success "Python 3 gefunden: $($PYTHON3 --version)"

# PyObjC prüfen und bei Bedarf installieren
if ! $PYTHON3 -c "import objc, AppKit, Foundation" 2>/dev/null; then
    info "Installiere PyObjC (Python-Abhängigkeit für Linky)..."
    # pip ermitteln
    PIP=""
    for p in "$PYTHON3 -m pip" "pip3" "pip"; do
        if eval "$p --version" &>/dev/null 2>&1; then
            PIP="$p"
            break
        fi
    done
    if [[ -z "$PIP" ]]; then
        # pip selbst installieren
        info "Installiere pip..."
        curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON3 || error "pip konnte nicht installiert werden."
        PIP="$PYTHON3 -m pip"
    fi
    eval "$PIP install --quiet --upgrade pyobjc" || \
        eval "$PIP install --quiet --upgrade --user pyobjc" || \
        error "PyObjC konnte nicht installiert werden.\nManuell: pip3 install pyobjc"
    success "PyObjC installiert"
else
    success "PyObjC bereits installiert"
fi

# =============================================================================
# Neueste Linky-Version herunterladen und installieren
# =============================================================================

info "Suche neueste Version..."
API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) || \
    error "GitHub API nicht erreichbar. Bitte Internetverbindung prüfen."

VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
DMG_URL=$(echo "$API_RESPONSE" | grep '"browser_download_url"' | grep '\.dmg"' | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

[[ -n "$VERSION" ]] || error "Keine Version gefunden. Bitte manuell von https://github.com/${GITHUB_REPO}/releases installieren."
[[ -n "$DMG_URL" ]] || error "Kein DMG-Download für Version ${VERSION} gefunden."

info "Installiere Linky ${VERSION}..."

# Temporäre Dateien
TMP_DMG=$(mktemp /tmp/Linky-XXXXXX.dmg)
TMP_MOUNT=$(mktemp -d /tmp/linky-mount-XXXXXX)

cleanup() {
    hdiutil detach "$TMP_MOUNT" -quiet 2>/dev/null || true
    rm -f "$TMP_DMG"
    rm -rf "$TMP_MOUNT"
}
trap cleanup EXIT

# DMG herunterladen
info "Lade DMG herunter..."
curl -fsSL --progress-bar "$DMG_URL" -o "$TMP_DMG" || error "Download fehlgeschlagen."

# DMG einhängen
info "Öffne Installer-Image..."
hdiutil attach "$TMP_DMG" -mountpoint "$TMP_MOUNT" -quiet -nobrowse || \
    error "Konnte DMG nicht einhängen."

# App kopieren
[[ -d "$TMP_MOUNT/${APP_NAME}.app" ]] || error "${APP_NAME}.app nicht im DMG gefunden."

info "Installiere ${APP_NAME}.app nach ${INSTALL_DIR}..."
if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
    warn "Alte Version wird ersetzt..."
    rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
fi
cp -R "$TMP_MOUNT/${APP_NAME}.app" "$INSTALL_DIR/"

# Quarantine-Flag entfernen (verhindert Gatekeeper-Warnung)
info "Entferne macOS Sicherheitssperre (Quarantine)..."
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

success "Linky ${VERSION} erfolgreich installiert!"
echo ""
echo -e "  ${GREEN}→${NC} App: ${INSTALL_DIR}/${APP_NAME}.app"
echo -e "  ${GREEN}→${NC} Finder Quick Action wird beim ersten Start automatisch eingerichtet"
echo ""

# App starten
info "Starte Linky..."
open "${INSTALL_DIR}/${APP_NAME}.app"

echo ""
echo -e "${GREEN}Fertig!${NC} Linky läuft in der Menüleiste (🔗)"
echo "Der Quick Action 'SMB-Link kopieren' ist jetzt im Finder-Rechtsklick-Menü verfügbar."
echo ""
