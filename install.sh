#!/bin/bash
# =============================================================================
# Linky - Installer
# =============================================================================
# Installiert Linky automatisch:
#   - Lädt die neueste Version herunter
#   - Installiert die App nach /Applications
#   - Entfernt den macOS Quarantine-Flag (verhindert Sicherheitswarnung)
#   - Startet die App (Finder Quick Action wird automatisch eingerichtet)
#
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

info()  { echo -e "${GREEN}▶${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✖ Fehler:${NC} $1"; exit 1; }
done()  { echo -e "${GREEN}✔${NC} $1"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Linky Installer            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════╝${NC}"
echo ""

# Systemcheck
if [[ "$(uname)" != "Darwin" ]]; then
    error "Linky läuft nur auf macOS."
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 12 ]]; then
    error "macOS 12 (Monterey) oder neuer erforderlich."
fi

# Neueste Version ermitteln
info "Suche neueste Version..."
API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) || \
    error "GitHub API nicht erreichbar. Bitte Internetverbindung prüfen."

VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
DMG_URL=$(echo "$API_RESPONSE" | grep '"browser_download_url"' | grep '\.dmg"' | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

if [[ -z "$VERSION" ]]; then
    error "Keine Version gefunden. Bitte manuell von https://github.com/${GITHUB_REPO}/releases installieren."
fi

if [[ -z "$DMG_URL" ]]; then
    error "Kein DMG-Download für Version ${VERSION} gefunden."
fi

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
curl -fsSL --progress-bar "$DMG_URL" -o "$TMP_DMG" || \
    error "Download fehlgeschlagen."

# DMG einhängen
info "Öffne Installer-Image..."
hdiutil attach "$TMP_DMG" -mountpoint "$TMP_MOUNT" -quiet -nobrowse || \
    error "Konnte DMG nicht einhängen."

# App kopieren
if [[ ! -d "$TMP_MOUNT/${APP_NAME}.app" ]]; then
    error "${APP_NAME}.app nicht im DMG gefunden."
fi

info "Installiere ${APP_NAME}.app nach ${INSTALL_DIR}..."
if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
    warn "Alte Version wird ersetzt..."
    rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
fi
cp -R "$TMP_MOUNT/${APP_NAME}.app" "$INSTALL_DIR/"

# Quarantine-Flag entfernen (verhindert Gatekeeper-Warnung)
info "Entferne macOS Sicherheitssperre (Quarantine)..."
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

done "Linky ${VERSION} erfolgreich installiert!"
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
