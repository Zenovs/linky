#!/bin/bash
# Linky - Abhängigkeiten installieren
# v2.0.1

echo "========================================"
echo "  Linky - Abhängigkeiten installieren"
echo "  Version 2.0.1"
echo "========================================"
echo ""

# Farben für Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Python 3 prüfen
echo "🔍 Suche nach Python 3..."
PYTHON3=""
for p in /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3 python3; do
    if command -v "$p" &>/dev/null; then
        PYTHON3="$p"
        break
    fi
done

if [ -z "$PYTHON3" ]; then
    echo -e "${RED}❌ Python 3 nicht gefunden!${NC}"
    echo ""
    echo "Bitte installieren Sie Python 3:"
    echo "  1. Homebrew: brew install python3"
    echo "  2. Oder: https://www.python.org/downloads/"
    echo ""
    read -p "Drücken Sie Enter zum Schließen..."
    exit 1
fi

echo -e "${GREEN}✅ Python 3 gefunden: $PYTHON3${NC}"
$PYTHON3 --version
echo ""

# pip3 prüfen
echo "🔍 Suche nach pip3..."
if ! command -v pip3 &>/dev/null; then
    echo -e "${YELLOW}⚠️  pip3 nicht direkt verfügbar, verwende Python-Modul${NC}"
    PIP_CMD="$PYTHON3 -m pip"
else
    PIP_CMD="pip3"
fi
echo ""

# PyObjC installieren
echo "📦 Installiere PyObjC..."
echo "   (Dies kann einige Minuten dauern)"
echo ""

$PIP_CMD install --upgrade pyobjc

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✅ Installation erfolgreich!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Sie können jetzt Linky starten."
    echo ""
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ❌ Installation fehlgeschlagen${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Versuchen Sie:"
    echo "  pip3 install --user pyobjc"
    echo ""
    echo "Oder mit sudo (nicht empfohlen):"
    echo "  sudo pip3 install pyobjc"
    echo ""
fi

read -p "Drücken Sie Enter zum Schließen..."
