# 🔗 Linky

**Linky** ist eine leichtgewichtige macOS Menu Bar App, die SMB-Links (Netzwerkfreigaben) nahtlos handhabt.

*[English version below](#-linky-english)*

---

## ⚡ Installation — ein Befehl

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

> Lädt die neueste Version herunter, installiert sie in `/Applications`, entfernt das Quarantine-Flag und startet die App.

---

## ✨ Features

- **🖱️ Rechtsklick → SMB-Link kopieren** — SMB-Pfad einer Datei/Ordner in die Zwischenablage
- **🖱️ Rechtsklick → SMB-Link öffnen** — SMB-Pfad direkt im Finder öffnen
- **🌐 Browser/Mail → Dienste → Linky → SMB-Link öffnen** — markierten SMB-Link öffnen
- **📋 Automatisches Öffnen** — SMB-Links beim Einfügen (Cmd+V) automatisch öffnen
- **📊 Menu Bar** — Unauffällige Integration in der macOS-Menüleiste
- **🚀 Autostart** — Optionaler Start beim Anmelden
- **🔄 Auto-Update** — Automatische Prüfung auf neue Versionen

## 📸 Screenshots

| Menu Bar | Einstellungen |
|----------|---------------|
| ![Menu Bar](docs/screenshots/menubar.png) | ![Settings](docs/screenshots/settings.png) |

## 📥 Weitere Installationsmethoden

### DMG manuell herunterladen
1. Lade die neueste [Linky-vX.X.X-macOS12+.dmg](https://github.com/Zenovs/linky/releases/latest) herunter
2. Öffne die DMG-Datei und ziehe **Linky.app** in den **Programme**-Ordner
3. Falls eine Sicherheitswarnung erscheint:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Linky.app
   ```

### Aus Quellcode bauen
Siehe [BUILD.md](docs/BUILD.md).

## 🎯 Verwendung

### SMB-Link kopieren (Finder)
1. Rechtsklick auf eine Datei/Ordner im Finder
2. **Schnellaktionen** → **SMB-Link kopieren**
3. SMB-Link ist in der Zwischenablage

### SMB-Link öffnen (Finder)
1. Rechtsklick auf eine Datei/Ordner im Finder
2. **Schnellaktionen** → **SMB-Link öffnen**
3. Finder öffnet die Netzwerkfreigabe direkt

### SMB-Link öffnen (Browser, Mail, überall)
1. SMB-Link im Text markieren (z.B. `smb://server/freigabe/ordner`)
2. Rechtsklick → **Dienste** → **Linky** → **SMB-Link öffnen**

### Automatisches Öffnen
1. Kopiere einen SMB-Link
2. Drücke **Cmd+V** irgendwo
3. Linky öffnet automatisch den Netzwerkpfad im Finder

### Quick Actions aktivieren (einmalig)
Beim ersten Start erscheint ein Dialog. Klick auf **„Einstellungen öffnen"** → alle drei Einträge aktivieren.

## 💻 Systemanforderungen

- macOS 12 (Monterey) oder neuer
- ~10 MB Speicherplatz
- Keine zusätzlichen Abhängigkeiten

## 🔧 Berechtigungen

- **Bedienungshilfen** — Erkennen von Cmd+V
- **Mitteilungen** — Status-Benachrichtigungen
- **AppleEvents** — Öffnen von SMB-Freigaben im Finder

## 📝 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md).

## 📄 Lizenz

MIT License — Siehe [LICENSE](LICENSE).

---

# 🔗 Linky (English)

**Linky** is a lightweight macOS menu bar app that seamlessly handles SMB links (network shares).

---

## ⚡ Install — one command

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

> Downloads the latest release, installs to `/Applications`, removes the quarantine flag, and launches the app.

---

## ✨ Features

- **🖱️ Right-click → Copy SMB Link** — copy a file's SMB path to clipboard
- **🖱️ Right-click → Open SMB Link** — open SMB path directly in Finder
- **🌐 Browser/Mail → Services → Linky → Open SMB Link** — open selected SMB URL
- **📋 Auto-Open** — automatically open SMB links when pasting (Cmd+V)
- **📊 Menu Bar** — unobtrusive integration in the macOS menu bar
- **🚀 Autostart** — optional launch at login
- **🔄 Auto-Update** — automatic check for new versions

## 📥 Other Installation Methods

### Download DMG manually
1. Download the latest [Linky-vX.X.X-macOS12+.dmg](https://github.com/Zenovs/linky/releases/latest)
2. Open the DMG and drag **Linky.app** to **Applications**
3. If a security warning appears:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Linky.app
   ```

### Build from Source
See [BUILD.md](docs/BUILD.md).

## 🎯 Usage

### Copy SMB Link (Finder)
1. Right-click a file/folder in Finder
2. **Quick Actions** → **SMB-Link kopieren**
3. SMB link is now in clipboard

### Open SMB Link (Finder)
1. Right-click a file/folder in Finder
2. **Quick Actions** → **SMB-Link öffnen**
3. Finder opens the network share directly

### Open SMB Link (Browser, Mail, anywhere)
1. Select an SMB link text (e.g. `smb://server/share/folder`)
2. Right-click → **Services** → **Linky** → **SMB-Link öffnen**

### Auto-Open
1. Copy an SMB link
2. Press **Cmd+V** anywhere
3. Linky automatically opens the network path in Finder

### Enable Quick Actions (once)
On first launch a dialog appears. Click **"Open Settings"** → enable all three entries.

## 💻 System Requirements

- macOS 12 (Monterey) or newer
- ~10 MB disk space
- No additional dependencies

## 🔧 Permissions

- **Accessibility** — detect Cmd+V
- **Notifications** — status notifications
- **AppleEvents** — open SMB shares in Finder

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md).

## 📄 License

MIT License — See [LICENSE](LICENSE).
