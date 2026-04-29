#!/bin/bash
# =============================================================================
#  Linky – Linux Installer
#  Verwendung:
#    bash install.sh
#  Oder via curl:
#    curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/linux/install.sh | bash
# =============================================================================

set -euo pipefail

APP_NAME="Linky"
GITHUB_REPO="Zenovs/linky"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
SCRIPT_DEST="$BIN_DIR/linky"

# ── Farben ────────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[1;33m'
BLU=$'\033[0;34m'
DIM=$'\033[2m'
NC=$'\033[0m'

step() { echo -e "\n${BLU}${BOLD}▶ $*${NC}"; }
ok()   { echo -e "  ${GRN}✔${NC}  $*"; }
warn() { echo -e "  ${YLW}⚠${NC}  $*"; }
die()  { echo -e "\n  ${RED}✖  $*${NC}\n"; exit 1; }

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
echo -e "  ${DIM}SMB-Link Handler für Linux${NC}"
echo ""

# ── 1. Systemcheck ────────────────────────────────────────────────────────────
step "Systemvoraussetzungen prüfen"

[[ "$(uname)" == "Linux" ]] || die "Dieses Skript läuft nur auf Linux."

# Python 3
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 -c "import sys; print('.'.join(map(str,sys.version_info[:2])))")
    ok "Python ${PY_VER}"
else
    die "Python 3 nicht gefunden.\nBitte installieren: sudo apt install python3"
fi

# xdg-open
if command -v xdg-open &>/dev/null; then
    ok "xdg-open vorhanden"
else
    warn "xdg-open nicht gefunden – Dateimanager-Erkennung eingeschränkt"
fi

# ── 2. Skript herunterladen oder lokal kopieren ───────────────────────────────
step "Linky installieren"

mkdir -p "$BIN_DIR"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/linky.py"

if [[ -f "$SCRIPT_SRC" ]]; then
    # Lokale Installation (aus dem geklonten Repo)
    cp "$SCRIPT_SRC" "$SCRIPT_DEST"
    ok "Skript lokal kopiert"
else
    # Download von GitHub
    spin_start "Lade linky.py von GitHub…"
    curl -fsSL \
        "https://raw.githubusercontent.com/${GITHUB_REPO}/main/linux/linky.py" \
        -o "$SCRIPT_DEST" \
        || { spin_stop; die "Download fehlgeschlagen."; }
    spin_stop
    ok "Skript heruntergeladen"
fi

chmod +x "$SCRIPT_DEST"
ok "Installiert nach $SCRIPT_DEST"

# Sicherstellen, dass ~/.local/bin im PATH ist
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR ist nicht im PATH."
    warn "Füge dies in deine ~/.bashrc oder ~/.zshrc ein:"
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── 3. Python-Pakete ──────────────────────────────────────────────────────────
step "Python-Pakete installieren (pystray + Pillow)"

spin_start "Installiere Pakete…"
pip3 install --quiet --user pystray Pillow 2>/dev/null \
    || python3 -m pip install --quiet --user pystray Pillow 2>/dev/null \
    || true
spin_stop

if python3 -c "import pystray, PIL" 2>/dev/null; then
    ok "pystray und Pillow verfügbar"
else
    warn "pystray/Pillow nicht installiert – Tray-Icon nicht verfügbar"
    warn "Manuell installieren: pip3 install --user pystray Pillow"
fi

# ── 4. Protokoll-Handler registrieren ────────────────────────────────────────
step "smb:// Protokoll-Handler registrieren"

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_DIR/linky.desktop" << DESKTOP
[Desktop Entry]
Name=Linky
Comment=SMB-Link Handler – öffnet smb:// Links im Dateimanager
Exec=$SCRIPT_DEST %u
Icon=folder-network
Type=Application
NoDisplay=true
MimeType=x-scheme-handler/smb;
Categories=Network;FileManager;
DESKTOP

# Desktop-Datenbank zuerst aktualisieren, damit xdg-mime das neue .desktop findet
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# xdg-mime: smb:// → linky.desktop
if command -v xdg-mime &>/dev/null; then
    xdg-mime default linky.desktop x-scheme-handler/smb 2>/dev/null || true
    ok "xdg-mime: smb:// → linky registriert"
fi

# gio: alternative Registrierung für GNOME/Flatpak-Umgebungen
if command -v gio &>/dev/null; then
    gio mime x-scheme-handler/smb linky.desktop 2>/dev/null || true
    ok "gio: smb:// registriert"
fi

ok "Handler registriert: $DESKTOP_DIR/linky.desktop"

# ── 5. Autostart ──────────────────────────────────────────────────────────────
step "Autostart einrichten"

mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/linky.desktop" << AUTOSTART
[Desktop Entry]
Name=Linky
Comment=SMB-Link Handler
Exec=$SCRIPT_DEST
Type=Application
Hidden=false
X-GNOME-Autostart-enabled=true
AUTOSTART

ok "Autostart: $AUTOSTART_DIR/linky.desktop"

# ── 6. Daemon starten ─────────────────────────────────────────────────────────
step "Linky starten"

# Eventuell laufende Instanz beenden
pkill -f "$SCRIPT_DEST" 2>/dev/null || true
sleep 0.3

"$SCRIPT_DEST" &
DAEMON_PID=$!
sleep 1

if kill -0 "$DAEMON_PID" 2>/dev/null; then
    ok "Linky läuft (PID $DAEMON_PID)"
else
    warn "Linky konnte nicht gestartet werden."
    warn "Manuell starten: $SCRIPT_DEST"
fi

# ── Fertig ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}${BOLD}  ✔ Installation abgeschlossen!${NC}"
echo ""
echo -e "  ${DIM}Skript:${NC}    $SCRIPT_DEST"
echo -e "  ${DIM}Handler:${NC}   smb:// → Linky → Dateimanager"
echo ""
echo -e "${YLW}${BOLD}  Nächste Schritte:${NC}"
echo ""
echo -e "  1. Klicke auf einen ${BOLD}smb://${NC} Link in Firefox, Chrome oder Nautilus"
echo -e "     → Der Dateimanager öffnet den Netzwerkpfad direkt."
echo ""
echo -e "  2. Falls der Browser fragt: ${BOLD}'Mit Linky öffnen'${NC} bestätigen."
echo ""
echo -e "  ${DIM}Deinstallieren:${NC}  bash $(dirname "${BASH_SOURCE[0]}")/uninstall.sh"
echo ""
