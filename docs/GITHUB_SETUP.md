# GitHub Setup-Anleitung

Schritt-für-Schritt-Anleitung zum Einrichten des Linky GitHub-Repositorys.

## 1. Repository erstellen

### Via Web-Interface

1. Gehe zu [github.com/new](https://github.com/new)
2. Repository-Name: `linky`
3. Beschreibung: "macOS Menu Bar App für SMB-Links"
4. Public oder Private wählen
5. **OHNE** README, .gitignore oder License erstellen
6. **Create repository**

### Via GitHub CLI

```bash
gh repo create linky --public --description "macOS Menu Bar App für SMB-Links"
```

## 2. Code hochladen

```bash
# Im linky_project Verzeichnis
cd /path/to/linky_project

# Git initialisieren
git init

# Alle Dateien hinzufügen
git add .

# Initialer Commit
git commit -m "Initial commit: Linky v2.0.0"

# Remote hinzufügen (ERSETZE Zenovs)
git remote add origin https://github.com/Zenovs/linky.git

# Zum GitHub hochladen
git branch -M main
git push -u origin main
```

## 3. Update-URL konfigurieren

### In den Source-Dateien anpassen

**Python (src/linky.py):**
```python
GITHUB_REPO = "Zenovs/linky"
```

**Swift (swift_version/Linky/AppDelegate.swift):**
```swift
let githubRepo = "Zenovs/linky"
```

### Änderungen committen

```bash
git add .
git commit -m "Update: GitHub username konfiguriert"
git push
```

## 4. Ersten Release erstellen

### DMG vorbereiten

1. Baue die App auf macOS:
   ```bash
   ./build_scripts/build_swift.sh
   ```

2. Erstelle DMG:
   ```bash
   ./build_scripts/create_dmg.sh
   ```

### Release auf GitHub

1. Gehe zu deinem Repository → **Releases** → **Create a new release**

2. **Tag**: `v2.0.0` (neuen Tag erstellen)

3. **Release title**: `Linky v2.0.0`

4. **Beschreibung**:
   ```markdown
   ## Linky v2.0.0
   
   Erste Veröffentlichung!
   
   ### Download
   - **Linky-v2.0.0-macOS12+.dmg** - Installer für macOS 12+
   
   ### Features
   - 📋 SMB-Link kopieren (Finder Quick Action)
   - 🔗 Automatisches Öffnen von SMB-Links
   - 📊 Menu Bar Integration
   - 🚀 Autostart-Option
   - 🔄 Auto-Update-Prüfung
   
   ### Installation
   1. DMG öffnen
   2. `Linky.app` in Programme ziehen
   3. `SMB-Link kopieren.workflow` in ~/Library/Services ziehen
   
   ### Systemanforderungen
   - macOS 12 (Monterey) oder neuer
   ```

5. **Datei hochladen**: `Linky-v2.0.0-macOS12+.dmg`

6. **Publish release**

## 5. Repository-Einstellungen

### Topics hinzufügen

1. Repository → **About** (Zahnrad-Icon)
2. Topics: `macos`, `menu-bar-app`, `smb`, `swift`, `python`, `network-shares`

### Releases-Badge hinzufügen

Füge dieses Badge zur README hinzu:

```markdown
[![GitHub Release](https://img.shields.io/github/v/release/Zenovs/linky)](https://github.com/Zenovs/linky/releases/latest)
```

## 6. Auto-Update testen

1. Installiere Linky v2.0.0
2. Prüfe ob "Nach Updates suchen..." funktioniert
3. Die App sollte die GitHub API abfragen und die aktuelle Version finden

```bash
# Teste die API manuell
curl -s https://api.github.com/repos/Zenovs/linky/releases/latest | jq '.tag_name'
```

## 7. Optional: GitHub Actions

Für automatische Builds bei jedem Release, füge `.github/workflows/build.yml` hinzu.

Da macOS-Builds auf GitHub Actions kostenpflichtig sind, ist dies optional.

---

## Zusammenfassung

1. ☐ Repository erstellt
2. ☐ Code hochgeladen
3. ☐ GitHub username in Source-Dateien eingetragen
4. ☐ DMG gebaut und hochgeladen
5. ☐ Ersten Release erstellt
6. ☐ Auto-Update getestet

Bei Fragen: [Issues erstellen](https://github.com/Zenovs/linky/issues)
