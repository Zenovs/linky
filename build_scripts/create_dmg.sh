#!/bin/bash
# =============================================================================
# Linky - DMG Creation Script
# =============================================================================
# Creates a distributable DMG installer for Linky
#
# Usage:
#   ./build_scripts/create_dmg.sh
#
# Requirements:
#   - macOS 12+
#   - Linky.app must be built first (run build_swift.sh or build_python.sh)
# =============================================================================

set -e

# Configuration
APP_NAME="Linky"
VERSION="2.0.0"
DMG_NAME="Linky-v${VERSION}-macOS12+.dmg"
VOLUME_NAME="Linky"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$PROJECT_DIR/dmg_staging"
WORKFLOW_DIR="$PROJECT_DIR/workflow"
APP_PATH="$DIST_DIR/$APP_NAME.app"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check requirements
if [[ "$(uname)" != "Darwin" ]]; then
    error "This script must be run on macOS"
fi

if [[ ! -d "$APP_PATH" ]]; then
    error "App not found at $APP_PATH. Please build first:"
    error "  ./build_scripts/build_swift.sh"
    error "  or"
    error "  ./build_scripts/build_python.sh"
fi

info "Creating DMG for $APP_NAME v$VERSION"

# Clean and create staging directory
info "Preparing staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy app
info "Copying app bundle..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# Copy workflow if exists
if [[ -d "$WORKFLOW_DIR/SMB-Link kopieren.workflow" ]]; then
    info "Copying workflow..."
    cp -R "$WORKFLOW_DIR/SMB-Link kopieren.workflow" "$STAGING_DIR/"
elif [[ -d "$PROJECT_DIR/SMB-Link kopieren.workflow" ]]; then
    cp -R "$PROJECT_DIR/SMB-Link kopieren.workflow" "$STAGING_DIR/"
fi

# Create symlinks
info "Creating symbolic links..."
ln -s /Applications "$STAGING_DIR/Applications"
ln -s ~/Library/Services "$STAGING_DIR/Workflow hier ablegen"

# Create README
info "Creating README..."
cat > "$STAGING_DIR/LIES_MICH.txt" << 'EOF'
================================================================================
                          Linky - Installation
================================================================================

WILLKOMMEN BEI LINKY!

Linky ist eine macOS Menu Bar App, die SMB-Links (Netzwerkfreigaben) handhabt.

--------------------------------------------------------------------------------
INSTALLATION
--------------------------------------------------------------------------------

1. APP INSTALLIEREN:
   Ziehe "Linky.app" in den "Applications" Ordner (Alias in diesem Fenster)

2. WORKFLOW INSTALLIEREN (optional):
   Ziehe "SMB-Link kopieren.workflow" in den "Workflow hier ablegen" Ordner
   
   Dieser Workflow fügt eine "SMB-Link kopieren" Option zum Rechtsklick-Menü
   im Finder hinzu.

3. APP STARTEN:
   - Öffne Linky aus dem Programme-Ordner
   - Ein 🔗-Symbol erscheint in der Menüleiste
   
   Falls die App als "beschädigt" gemeldet wird:
   Rechtsklick auf die App -> "Öffnen" wählen
   ODER im Terminal: xattr -d com.apple.quarantine /Applications/Linky.app

--------------------------------------------------------------------------------
FUNKTIONEN
--------------------------------------------------------------------------------

- SMB-Link kopieren: Rechtsklick -> Schnellaktionen -> SMB-Link kopieren
- Auto-Open: SMB-Links aus der Zwischenablage werden automatisch geöffnet
- Autostart: Optional beim Anmelden starten
- Auto-Update: Prüft automatisch auf neue Versionen

--------------------------------------------------------------------------------
SYSTEMANFORDERUNGEN
--------------------------------------------------------------------------------

- macOS 12 (Monterey) oder neuer

--------------------------------------------------------------------------------
HILFE & UPDATES
--------------------------------------------------------------------------------

GitHub: https://github.com/Zenovs/linky
Updates werden automatisch geprüft (konfigurierbar im Menü)

================================================================================
EOF

# Remove old DMG if exists
rm -f "$PROJECT_DIR/$DMG_NAME"

# Create DMG
info "Creating DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$PROJECT_DIR/$DMG_NAME"

# Cleanup
info "Cleaning up..."
rm -rf "$STAGING_DIR"

info "DMG created successfully!"
info "Output: $PROJECT_DIR/$DMG_NAME"
info ""
info "To upload to GitHub Release:"
info "  gh release upload v$VERSION $PROJECT_DIR/$DMG_NAME"
