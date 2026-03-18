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

# Spinner: spin_start "Nachricht" → hält im Hintergrund → spin_stop
SPIN_PID=""
spin_start() {
    local msg="$1"
    (
        local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while true; do
            printf "\r  ${BLUE}${frames:$i:1}${NC} %s" "$msg"
            i=$(( (i+1) % 10 ))
            sleep 0.1
        done
    ) &
    SPIN_PID=$!
}
spin_stop() {
    [[ -n "$SPIN_PID" ]] && kill "$SPIN_PID" 2>/dev/null; SPIN_PID=""
    printf "\r\033[K"   # Zeile löschen
}

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
# 1. Python 3
# =============================================================================
info "Prüfe Python 3..."

PYTHON3=""
for p in /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3 python3; do
    if command -v "$p" &>/dev/null; then
        PYTHON3="$p"
        break
    fi
done

if [[ -z "$PYTHON3" ]]; then
    warn "Python 3 nicht gefunden – starte Xcode Command Line Tools Installation..."
    xcode-select --install 2>/dev/null || true

    echo ""
    echo -e "${YELLOW}  → Ein Dialogfenster wurde geöffnet.${NC}"
    echo -e "${YELLOW}    Bitte auf 'Installieren' klicken und abwarten.${NC}"
    echo ""

    spin_start "Warte auf Abschluss der Installation (kann mehrere Minuten dauern)..."
    WAITED=0
    until command -v /usr/bin/python3 &>/dev/null || command -v python3 &>/dev/null; do
        sleep 5
        WAITED=$((WAITED + 5))
        if [[ $WAITED -ge 600 ]]; then
            spin_stop
            error "Timeout nach 10 Minuten.\nBitte Python manuell installieren: https://www.python.org/downloads/"
        fi
    done
    spin_stop

    for p in /usr/bin/python3 /usr/local/bin/python3 python3; do
        if command -v "$p" &>/dev/null; then PYTHON3="$p"; break; fi
    done
fi

success "Python 3: $($PYTHON3 --version)"

# =============================================================================
# 2. pip
# =============================================================================
PIP=""
for p in "pip3" "$PYTHON3 -m pip" "pip"; do
    if eval "$p --version" &>/dev/null 2>&1; then
        PIP="$p"; break
    fi
done

if [[ -z "$PIP" ]]; then
    info "pip nicht gefunden – installiere pip..."
    spin_start "Installiere pip..."
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON3 -q
    spin_stop
    PIP="$PYTHON3 -m pip"
    success "pip installiert"
fi

# =============================================================================
# 3. PyObjC
# =============================================================================
if ! $PYTHON3 -c "import objc, AppKit, Foundation" 2>/dev/null; then
    info "Installiere PyObjC..."
    echo ""

    # Fortschritt sichtbar (kein --quiet)
    eval "$PIP install --upgrade pyobjc" 2>&1 | while IFS= read -r line; do
        # Nur relevante Zeilen anzeigen
        if [[ "$line" == Collecting* ]] || [[ "$line" == Installing* ]] || \
           [[ "$line" == Successfully* ]] || [[ "$line" == Downloading* ]]; then
            echo -e "    ${BLUE}→${NC} $line"
        fi
    done || \
    eval "$PIP install --upgrade --user pyobjc" 2>&1 | grep -E "Collecting|Installing|Successfully|Downloading" | \
        while IFS= read -r line; do echo -e "    ${BLUE}→${NC} $line"; done || \
        error "PyObjC konnte nicht installiert werden.\nManuell: pip3 install pyobjc"

    echo ""
    success "PyObjC installiert"
else
    success "PyObjC bereits vorhanden"
fi

# =============================================================================
# 4. Linky herunterladen
# =============================================================================
info "Suche neueste Linky-Version..."
API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) || \
    error "GitHub API nicht erreichbar."

VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
DMG_URL=$(echo "$API_RESPONSE" | grep '"browser_download_url"' | grep '\.dmg"' | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

[[ -n "$VERSION" ]] || error "Keine Version auf GitHub gefunden."
[[ -n "$DMG_URL" ]] || error "Kein DMG für Version ${VERSION} gefunden."

info "Version ${VERSION} gefunden – lade DMG herunter..."
echo ""

TMP_DMG=$(mktemp /tmp/Linky-XXXXXX.dmg)
TMP_MOUNT=$(mktemp -d /tmp/linky-mount-XXXXXX)
cleanup() {
    hdiutil detach "$TMP_MOUNT" -quiet 2>/dev/null || true
    rm -f "$TMP_DMG"
    rm -rf "$TMP_MOUNT"
}
trap cleanup EXIT

# curl zeigt nativen Fortschrittsbalken
curl -fL --progress-bar "$DMG_URL" -o "$TMP_DMG" || error "Download fehlgeschlagen."
echo ""

# =============================================================================
# 5. App installieren
# =============================================================================
spin_start "Öffne Installer-Image..."
hdiutil attach "$TMP_DMG" -mountpoint "$TMP_MOUNT" -quiet -nobrowse || \
    { spin_stop; error "Konnte DMG nicht einhängen."; }
spin_stop
success "DMG eingehängt"

[[ -d "$TMP_MOUNT/${APP_NAME}.app" ]] || error "${APP_NAME}.app nicht im DMG gefunden."

spin_start "Kopiere ${APP_NAME}.app nach ${INSTALL_DIR}..."
if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
    rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
fi
cp -R "$TMP_MOUNT/${APP_NAME}.app" "$INSTALL_DIR/"
spin_stop
success "App installiert"

# =============================================================================
# 6. Launcher aktualisieren (stellt sicher dass neueste Version verwendet wird)
# =============================================================================
spin_start "Aktualisiere App-Launcher..."
LAUNCHER_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/src/launcher.sh"
LAUNCHER_DEST="${INSTALL_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
curl -fsSL "$LAUNCHER_URL" -o "$LAUNCHER_DEST" 2>/dev/null && \
    chmod +x "$LAUNCHER_DEST" || true
spin_stop
success "Launcher aktualisiert"

# =============================================================================
# 7. Quarantine entfernen
# =============================================================================
spin_start "Entferne macOS Sicherheitssperre..."
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true
spin_stop
success "Quarantine entfernt"

# =============================================================================
# 8. App starten & prüfen
# =============================================================================
info "Starte Linky..."
open "${INSTALL_DIR}/${APP_NAME}.app"

# Kurz warten und prüfen ob der Prozess läuft
sleep 4
if pgrep -f "linky.py" > /dev/null 2>&1 || pgrep -f "Linky" > /dev/null 2>&1; then
    echo ""
    success "Linky läuft!"
else
    echo ""
    warn "Linky scheint nicht gestartet zu sein."
    warn "Log: ~/Library/Logs/Linky.log"
    echo ""
    echo -e "  Manuell starten:"
    echo -e "  ${BLUE}open /Applications/Linky.app${NC}"
    echo ""
    echo -e "  Log anzeigen:"
    echo -e "  ${BLUE}cat ~/Library/Logs/Linky.log${NC}"
fi

echo ""
echo -e "  ${GREEN}→${NC} App: ${INSTALL_DIR}/${APP_NAME}.app"
echo -e "  ${GREEN}→${NC} Finder Quick Action wird beim ersten Start automatisch eingerichtet"
echo -e "  ${GREEN}→${NC} Menüleiste: 🔗-Symbol"
echo ""
echo -e "${GREEN}Installation abgeschlossen!${NC}"
echo ""
