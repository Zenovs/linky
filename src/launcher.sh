#!/bin/bash
# Linky Launcher Script v2.1.0
# Installiert fehlende Abhängigkeiten automatisch und startet die App

APP_NAME="Linky"
APP_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/../Resources"
LOG_FILE="$HOME/Library/Logs/Linky.log"

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

log "$APP_NAME v$APP_VERSION wird gestartet..."

# Python 3 finden
PYTHON3=""
for p in /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3 python3; do
    if command -v "$p" &>/dev/null; then
        PYTHON3="$p"
        break
    fi
done

if [[ -z "$PYTHON3" ]]; then
    log "FEHLER: Python 3 nicht gefunden"
    osascript -e "display dialog \"Python 3 wurde nicht gefunden.\n\nBitte installieren Sie Linky über den Installer:\n\ncurl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash\" buttons {\"OK\"} default button 1 with title \"$APP_NAME - Fehler\" with icon stop"
    exit 1
fi

log "Python 3: $($PYTHON3 --version 2>&1)"

# PyObjC prüfen und bei Bedarf still im Hintergrund installieren
if ! $PYTHON3 -c "import objc, AppKit, Foundation" 2>/dev/null; then
    log "PyObjC nicht gefunden – installiere automatisch im Hintergrund..."

    PIP_CMD=""
    for p in "pip3" "$PYTHON3 -m pip" "pip"; do
        if eval "$p --version" &>/dev/null 2>&1; then
            PIP_CMD="$p"
            break
        fi
    done

    if [[ -n "$PIP_CMD" ]]; then
        eval "$PIP_CMD install --quiet --upgrade pyobjc" >> "$LOG_FILE" 2>&1 || \
        eval "$PIP_CMD install --quiet --upgrade --user pyobjc" >> "$LOG_FILE" 2>&1 || true
    fi

    # Nochmal prüfen
    if ! $PYTHON3 -c "import objc, AppKit, Foundation" 2>/dev/null; then
        log "FEHLER: PyObjC konnte nicht installiert werden"
        osascript -e "display dialog \"PyObjC konnte nicht installiert werden.\n\nBitte führen Sie im Terminal aus:\npip3 install pyobjc\n\nOder installieren Sie Linky neu:\ncurl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash\" buttons {\"OK\"} default button 1 with title \"$APP_NAME - Fehler\" with icon stop"
        exit 1
    fi

    log "PyObjC erfolgreich installiert"
fi

log "PyObjC OK – starte linky.py"
cd "$RESOURCES_DIR"
exec $PYTHON3 "$RESOURCES_DIR/linky.py" 2>> "$LOG_FILE"
