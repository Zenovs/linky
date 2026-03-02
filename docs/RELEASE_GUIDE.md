# Release Guide

Diese Anleitung beschreibt, wie eine neue Linky-Version veröffentlicht wird.

## Versionsschema (Semantic Versioning)

Linky verwendet [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (z.B. `2.0.0`)
  - **MAJOR**: Inkompatible Änderungen
  - **MINOR**: Neue Features (abwärtskompatibel)
  - **PATCH**: Bugfixes

## Checkliste vor dem Release

### 1. Version aktualisieren

Aktualisiere die Version in folgenden Dateien:

**Python-Version:**
```python
# src/linky.py
APP_VERSION = "2.1.0"  # Neue Version

# setup.py
VERSION = '2.1.0'
```

**Swift-Version:**
```swift
// swift_version/Linky/AppDelegate.swift
let appVersion = "2.1.0"

// swift_version/Linky/Info.plist
<key>CFBundleShortVersionString</key>
<string>2.1.0</string>
<key>CFBundleVersion</key>
<string>2.1.0</string>
```

### 2. CHANGELOG aktualisieren

```markdown
## [2.1.0] - YYYY-MM-DD

### Hinzugefügt
- Neue Funktion XYZ

### Geändert
- Verbesserte ABC

### Behoben
- Bug in DEF
```

### 3. App bauen

```bash
# Swift-Version (empfohlen)
./build_scripts/build_swift.sh

# Oder Python-Version
python setup.py py2app
```

### 4. Testen

- [ ] App startet korrekt
- [ ] Menu Bar Icon erscheint
- [ ] SMB-Link kopieren Workflow funktioniert
- [ ] Auto-Open funktioniert
- [ ] Autostart funktioniert
- [ ] Update-Check funktioniert
- [ ] Benachrichtigungen werden angezeigt

### 5. DMG erstellen

```bash
./build_scripts/create_dmg.sh
```

Das Ergebnis: `Linky-v2.1.0-macOS12+.dmg`

## GitHub Release erstellen

### Via Web-Interface

1. Gehe zu **Releases** → **Draft a new release**
2. Tag: `v2.1.0` (neuen Tag erstellen)
3. Release title: `Linky v2.1.0`
4. Beschreibung: Kopiere den CHANGELOG-Eintrag
5. Datei hochladen: `Linky-v2.1.0-macOS12+.dmg`
6. **Publish release**

### Via GitHub CLI

```bash
# Release erstellen
gh release create v2.1.0 \
    --title "Linky v2.1.0" \
    --notes-file release_notes.md \
    Linky-v2.1.0-macOS12+.dmg
```

## Nach dem Release

### Update-URL prüfen

Stelle sicher, dass die GitHub API die neue Version zurückgibt:

```bash
curl -s https://api.github.com/repos/Zenovs/linky/releases/latest | jq '.tag_name'
# Sollte "v2.1.0" zurückgeben
```

### Release testen

1. Lade die DMG vom Release herunter
2. Installiere die App
3. Prüfe, ob die alte Version ein Update findet

## Hotfix-Prozess

Für dringende Bugfixes:

1. Branch vom aktuellen Release-Tag: `git checkout -b hotfix/2.1.1 v2.1.0`
2. Fix implementieren
3. Version zu `2.1.1` erhöhen
4. Normalen Release-Prozess durchführen

## Release-Vorlage

```markdown
## Linky v2.1.0

### Download
- **[Linky-v2.1.0-macOS12+.dmg](link)** (XX MB)

### Installation
1. DMG öffnen
2. Linky.app in Programme ziehen
3. Workflow in ~/Library/Services ziehen

### Änderungen
<!-- CHANGELOG-Eintrag hier -->

### Systemanforderungen
- macOS 12 (Monterey) oder neuer
```
