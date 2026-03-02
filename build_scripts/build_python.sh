#!/bin/bash
# =============================================================================
# Linky - Python/PyObjC Build Script
# =============================================================================
# Builds the Python version of Linky using py2app
#
# Usage:
#   ./build_scripts/build_python.sh
#
# Requirements:
#   - macOS 12+
#   - Python 3.9+
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

cd "$PROJECT_DIR"

# Check requirements
info "Checking requirements..."

if [[ "$(uname)" != "Darwin" ]]; then
    error "This script must be run on macOS"
fi

if ! command -v python3 &> /dev/null; then
    error "Python 3 not found. Please install Python 3.9+"
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
info "Python version: $PYTHON_VERSION"

# Create virtual environment if it doesn't exist
if [[ ! -d "venv" ]]; then
    info "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
info "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
info "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Generate icon if needed
if [[ -f "Resources/AppIcon.png" ]] && [[ ! -f "Resources/AppIcon.icns" ]]; then
    info "Generating app icon..."
    
    ICONSET="Resources/AppIcon.iconset"
    mkdir -p "$ICONSET"
    
    sips -z 16 16 Resources/AppIcon.png --out "$ICONSET/icon_16x16.png" 2>/dev/null || true
    sips -z 32 32 Resources/AppIcon.png --out "$ICONSET/icon_16x16@2x.png" 2>/dev/null || true
    sips -z 32 32 Resources/AppIcon.png --out "$ICONSET/icon_32x32.png" 2>/dev/null || true
    sips -z 64 64 Resources/AppIcon.png --out "$ICONSET/icon_32x32@2x.png" 2>/dev/null || true
    sips -z 128 128 Resources/AppIcon.png --out "$ICONSET/icon_128x128.png" 2>/dev/null || true
    sips -z 256 256 Resources/AppIcon.png --out "$ICONSET/icon_128x128@2x.png" 2>/dev/null || true
    sips -z 256 256 Resources/AppIcon.png --out "$ICONSET/icon_256x256.png" 2>/dev/null || true
    sips -z 512 512 Resources/AppIcon.png --out "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
    sips -z 512 512 Resources/AppIcon.png --out "$ICONSET/icon_512x512.png" 2>/dev/null || true
    sips -z 1024 1024 Resources/AppIcon.png --out "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
    
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns 2>/dev/null || warn "Could not create .icns"
    rm -rf "$ICONSET"
fi

# Clean previous builds
info "Cleaning previous builds..."
rm -rf build dist

# Build with py2app
info "Building app with py2app..."
python setup.py py2app

info "Build complete!"
info "App bundle: dist/Linky.app"
info ""
info "To install:"
info "  1. Copy dist/Linky.app to /Applications"
info "  2. Run: xattr -d com.apple.quarantine /Applications/Linky.app"
info "  3. Launch Linky from Applications"
