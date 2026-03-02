# Build-Anleitung

Linky kann auf zwei Arten gebaut werden: als native Swift-App oder als Python/PyObjC-App.

## Voraussetzungen

- macOS 12 (Monterey) oder neuer
- Xcode Command Line Tools: `xcode-select --install`

---

## Option 1: Swift-Version (empfohlen)

Die native Swift-Version ist schlanker und benötigt keine Python-Abhängigkeiten.

### Automatisch bauen

```bash
cd linky_project
./build_scripts/build_swift.sh
```

### Manuell bauen

```bash
cd swift_version/Linky

# Kompilieren
swiftc -o Linky \
    -target arm64-apple-macos12 \
    -target x86_64-apple-macos12 \
    AppDelegate.swift main.swift \
    -framework Cocoa \
    -framework UserNotifications

# App-Bundle erstellen
mkdir -p Linky.app/Contents/MacOS
mkdir -p Linky.app/Contents/Resources
mv Linky Linky.app/Contents/MacOS/
cp Info.plist Linky.app/Contents/
cp ../../Resources/AppIcon.png Linky.app/Contents/Resources/

# Code signieren (optional)
codesign --force --deep --sign - Linky.app
```

---

## Option 2: Python/PyObjC-Version

Die Python-Version eignet sich gut für schnelle Iterationen und Debugging.

### Voraussetzungen

- Python 3.9+
- pip

### Setup

```bash
# Virtual Environment erstellen
python3 -m venv venv
source venv/bin/activate

# Abhängigkeiten installieren
pip install -r requirements.txt
```

### App bauen

```bash
# py2app Build
python setup.py py2app

# Die App befindet sich in dist/Linky.app
```

### Im Entwicklungsmodus ausführen

```bash
python src/linky.py
```

---

## DMG erstellen

### Automatisch (empfohlen)

```bash
./build_scripts/create_dmg.sh
```

### Manuell

```bash
# Staging-Verzeichnis erstellen
mkdir -p dmg_staging
cp -R dist/Linky.app dmg_staging/
cp -R "SMB-Link kopieren.workflow" dmg_staging/
ln -s /Applications dmg_staging/Applications
ln -s ~/Library/Services dmg_staging/"Workflow hier ablegen"

# DMG erstellen
hdiutil create -volname "Linky" \
    -srcfolder dmg_staging \
    -ov -format UDZO \
    Linky-v2.0.0-macOS12+.dmg
```

---

## Icon generieren

Falls ein neues Icon benötigt wird:

```bash
# AppIcon.png sollte 1024x1024 sein
mkdir -p AppIcon.iconset

sips -z 16 16 AppIcon.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32 AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32 AppIcon.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64 AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128 AppIcon.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256 AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256 AppIcon.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512 AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512 AppIcon.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png

iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

---

## Troubleshooting

### "Cannot be opened because the developer cannot be verified"

```bash
# Quarantäne-Attribut entfernen
xattr -d com.apple.quarantine /Applications/Linky.app
```

### "Linky.app is damaged"

```bash
# Signatur entfernen und neu signieren
codesign --remove-signature /Applications/Linky.app
codesign --force --deep --sign - /Applications/Linky.app
```

### Python nicht gefunden

Stelle sicher, dass Python 3.9+ installiert ist:
```bash
brew install python@3.11
```
