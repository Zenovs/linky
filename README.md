# 🔗 Linky

**Linky** ist eine leichtgewichtige macOS Menu Bar App, die SMB-Links (Netzwerkfreigaben) nahtlos handhabt.

*[English version below](#-linky-english)*

---

## ✨ Features

- **🖱️ Rechtsklick-Integration**: SMB-Links mit einem Klick kopieren
- **📋 Automatisches Öffnen**: SMB-Links aus der Zwischenablage werden automatisch geöffnet
- **📊 Menu Bar**: Unauffällige Integration in der macOS-Menüleiste
- **🚀 Autostart**: Optionaler Start beim Anmelden
- **🔄 Auto-Update**: Automatische Prüfung auf neue Versionen via GitHub Releases

## 📸 Screenshots

| Menu Bar | Einstellungen |
|----------|---------------|
| ![Menu Bar](docs/screenshots/menubar.png) | ![Settings](docs/screenshots/settings.png) |

## 📥 Installation

### Option 1: Bash-Installer (empfohlen — ein Befehl, alles automatisch)

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

Erledigt alles: Download, Installation, Quarantine-Flag entfernen, App starten und Finder Quick Action einrichten.

### Option 2: DMG manuell herunterladen
1. Lade die neueste [Linky-vX.X.X-macOS12+.dmg](https://github.com/Zenovs/linky/releases/latest) herunter
2. Öffne die DMG-Datei
3. Ziehe **Linky.app** in deinen **Programme**-Ordner
4. Starte Linky — falls eine Sicherheitswarnung erscheint:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Linky.app
   ```

> Der Finder Quick Action „SMB-Link kopieren" wird beim ersten Start automatisch installiert.

### Option 3: Aus Quellcode bauen
Siehe [BUILD.md](docs/BUILD.md) für Anleitungen zum Kompilieren.

## 🎯 Verwendung

### SMB-Link kopieren (Workflow)
1. Rechtsklick auf eine Datei/Ordner im Finder
2. Wähle **Schnellaktionen** → **SMB-Link kopieren**
3. Der SMB-Link ist nun in der Zwischenablage

### Automatisches Öffnen (App)
1. Kopiere einen SMB-Link (z.B. `smb://server/freigabe/ordner`)
2. Drücke **Cmd+V** irgendwo
3. Linky öffnet automatisch den Netzwerkpfad im Finder

### Einstellungen
Klicke auf das 🔗-Symbol in der Menüleiste:
- **Automatisches Öffnen**: SMB-Links beim Einfügen öffnen
- **Bei Anmeldung starten**: App automatisch starten
- **Nach Updates suchen**: Automatische Update-Prüfung

## 💻 Systemanforderungen

- macOS 12 (Monterey) oder neuer
- ~10 MB Speicherplatz
- Für die Swift-Version: Keine zusätzlichen Abhängigkeiten
- Für die Python-Version: Python 3.9+ mit PyObjC

## 🔧 Berechtigungen

Linky benötigt folgende Berechtigungen:
- **Bedienungshilfen**: Zum Erkennen von Cmd+V
- **Mitteilungen**: Für Status-Benachrichtigungen
- **AppleEvents**: Zum Öffnen von SMB-Freigaben im Finder

## 📝 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md) für die vollständige Versionshistorie.

## 🤝 Mitwirken

Beiträge sind willkommen! Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für Details.

## 📄 Lizenz

MIT License - Siehe [LICENSE](LICENSE) für Details.

---

# 🔗 Linky (English)

**Linky** is a lightweight macOS menu bar app that seamlessly handles SMB links (network shares).

## ✨ Features

- **🖱️ Right-click Integration**: Copy SMB links with one click
- **📋 Auto-Open**: SMB links from clipboard are automatically opened
- **📊 Menu Bar**: Unobtrusive integration in macOS menu bar
- **🚀 Autostart**: Optional launch at login
- **🔄 Auto-Update**: Automatic check for new versions via GitHub Releases

## 📥 Installation

### Option 1: Bash Installer (recommended — one command, fully automatic)

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

Downloads, installs, removes the quarantine flag, and starts the app — all in one step.

### Option 2: Download DMG manually
1. Download the latest [Linky-vX.X.X-macOS12+.dmg](https://github.com/Zenovs/linky/releases/latest)
2. Open the DMG file
3. Drag **Linky.app** to your **Applications** folder
4. Launch Linky — if a security warning appears:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Linky.app
   ```

> The Finder Quick Action "SMB-Link kopieren" is installed automatically on first launch.

### Option 3: Build from Source
See [BUILD.md](docs/BUILD.md) for compilation instructions.

## 🎯 Usage

### Copy SMB Link (Workflow)
1. Right-click on a file/folder in Finder
2. Select **Quick Actions** → **SMB-Link kopieren**
3. The SMB link is now in your clipboard

### Auto-Open (App)
1. Copy an SMB link (e.g., `smb://server/share/folder`)
2. Press **Cmd+V** anywhere
3. Linky automatically opens the network path in Finder

### Settings
Click the 🔗 icon in the menu bar:
- **Automatisches Öffnen**: Open SMB links when pasting
- **Bei Anmeldung starten**: Auto-start app
- **Nach Updates suchen**: Automatic update checking

## 💻 System Requirements

- macOS 12 (Monterey) or newer
- ~10 MB disk space
- For Swift version: No additional dependencies
- For Python version: Python 3.9+ with PyObjC

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
