#!/bin/bash
# =============================================================================
# Linky - Swift Build Script
# =============================================================================
# Builds the native Swift version of Linky for macOS 12+
#
# Usage:
#   ./build_scripts/build_swift.sh
#
# Requirements:
#   - macOS 12+
#   - Xcode Command Line Tools (xcode-select --install)
# =============================================================================

set -e

# Configuration
APP_NAME="Linky"
VERSION="2.0.0"
BUNDLE_ID="com.linky.app"
MIN_MACOS="12.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SWIFT_DIR="$PROJECT_DIR/swift_version/Linky"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check requirements
info "Checking requirements..."

if [[ "$(uname)" != "Darwin" ]]; then
    error "This script must be run on macOS"
fi

if ! command -v swiftc &> /dev/null; then
    error "Swift compiler not found. Please install Xcode Command Line Tools: xcode-select --install"
fi

info "Swift version: $(swiftc --version | head -1)"

# Create output directory
info "Creating output directory..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_BUNDLE"

# Compile Swift files
info "Compiling Swift sources..."
cd "$SWIFT_DIR"

# Build for both architectures (Universal Binary)
swiftc -o "$OUTPUT_DIR/$APP_NAME" \
    -target arm64-apple-macos$MIN_MACOS \
    -target x86_64-apple-macos$MIN_MACOS \
    -O \
    -framework Cocoa \
    -framework UserNotifications \
    AppDelegate.swift main.swift

# Create app bundle structure
info "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

mv "$OUTPUT_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$SWIFT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy icon
if [[ -f "$PROJECT_DIR/Resources/AppIcon.png" ]]; then
    info "Generating app icon..."
    
    ICONSET="$PROJECT_DIR/Resources/AppIcon.iconset"
    mkdir -p "$ICONSET"
    
    # Generate all icon sizes
    sips -z 16 16 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_16x16.png" 2>/dev/null
    sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_32x32.png" 2>/dev/null
    sips -z 64 64 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_128x128.png" 2>/dev/null
    sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_256x256.png" 2>/dev/null
    sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$PROJECT_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" 2>/dev/null
    
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || warn "Could not create .icns file"
    rm -rf "$ICONSET"
    
    # Also copy PNG for fallback
    cp "$PROJECT_DIR/Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/"
else
    warn "AppIcon.png not found in Resources/"
fi

# Ad-hoc code sign
info "Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || warn "Code signing failed (non-critical)"

info "Build complete!"
info "App bundle: $APP_BUNDLE"
info ""
info "To install:"
info "  1. Copy $APP_NAME.app to /Applications"
info "  2. Run: xattr -d com.apple.quarantine /Applications/$APP_NAME.app"
info "  3. Launch $APP_NAME from Applications"
