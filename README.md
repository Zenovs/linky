# 🔗 Linky

**Linky** ist ein leichtgewichtiger Datei-Browser für macOS mit erstklassiger SMB-/NAS-Integration. Was als kleine Menüleisten-Utility für `smb://`-Links begann, ist seit v3.0.0 ein vollwertiger Finder-Alternative mit Tabs, Spotlight-Suche, NAS-Discovery und automatischem Mount.

*[English version below](#-linky-english)*

---

## ⚡ Installation — ein Befehl

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

> Lädt die neueste Version herunter, installiert sie in `/Applications`, entfernt das Quarantine-Flag und startet die App.

Bestehende Installationen aktualisieren sich automatisch: Menüleiste → **„Nach Updates suchen…"** oder beim nächsten Start.

---

## ✨ Features

### 📂 Datei-Browser
- **Browser-Fenster** mit Sidebar (Favoriten / NAS / Geräte) und Datei-Liste
- **Tabs** — ⌘T neuer Tab, ⌘W schließen, ⌘⇧[ / ⌘⇧] wechseln; jeder Tab hat eigene Location & History
- **Navigation** — Zurück/Vor (⌘[/⌘]), Aufwärts (⌘↑), klickbare Breadcrumb-Pfadleiste
- **Eigene Favoriten** ★ — beliebige Ordner / Dateien zur Sidebar pinnen, persistent
- **Externe Geräte live** — USB-Sticks & Festplatten erscheinen sofort beim Anschließen

### 🔍 Suche
- **Drei Scopes** in einer Suche:
  - **Aktueller Ordner** (Spotlight, schnell, fokussiert)
  - **Ganzer Mac** (Spotlight, system-weit)
  - **Alle NAS-Shares** (paralleler Walker, Streaming-Ergebnisse) — *Spotlight indiziert SMB nicht, Linky schon*
- **Type-to-Filter wie Ubuntu** — einfach im File-Bereich lostippen, Liste filtert live
- **Quick Look** mit Leertaste

### 📡 NAS / SMB (Linky-DNA)
- **Bonjour-Discovery** — SMB-Server im LAN erscheinen automatisch in der Sidebar unter „Im Netzwerk", kein „Verbinden mit Server"-Dialog mehr
- **Auto-Mount** ⚡ — Verknüpfung beim App-Start und Netzwerkwechsel (Wi-Fi → Ethernet, VPN-Connect) automatisch einbinden, lautlos wenn Credentials im Schlüsselbund
- **SMB-Bookmarks** — Server pinnen mit eigenem Namen, persistent über Neustarts
- **SMB-URL-Handler** — `smb://`-Links aus Browser/Mail öffnen direkt
- **Rechtsklick im Finder** → „SMB-Link kopieren" / „SMB-Link öffnen" (Quick Actions automatisch installiert)
- **Cmd+V Auto-Open** — SMB-Link in Zwischenablage → wird beim Einfügen automatisch geöffnet

### 📁 Datei-Operationen
| Aktion | Shortcut |
|---|---|
| Auswählen | Klick / ⌘-Klick / ⇧-Klick |
| Alle auswählen | ⌘A |
| Kopieren | ⌘C |
| Einfügen | ⌘V |
| Verschieben | ⌥⌘V |
| Duplizieren | ⌘D |
| Umbenennen | Kontextmenü |
| In Papierkorb | ⌘⌫ |
| Neuer Ordner | ⇧⌘N |
| Information | ⌘I |
| Vorschau | Leertaste |
| Im Finder anzeigen | Kontextmenü |

### 🎨 Design
- **Adaptives Theme** — Sage-Grün / Lavendel / Crème im Light Mode, Kupfer / Forest-Green / Charcoal im Dark Mode
- **Folgt der System-Einstellung** automatisch
- **Lokalisierte Pfadleiste** — Ordnernamen in System-Sprache (Schreibtisch/Desktop, Programme/Applications)
- **Transparent Title-Bar** + Full-Size-Content für moderne Browser-Optik

### 🖥 System-Integration
- **Dock-Icon** + **Menüleisten-Icon** parallel — App läuft auch wenn Fenster zu (Auto-Mount + Quick Actions weiter aktiv)
- **Autostart** optional beim Anmelden
- **Auto-Update** über GitHub Releases (täglicher Check, In-App-Install)

## 📸 Screenshots

| Light Mode | Dark Mode |
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

## 🎯 Quick-Start

1. **Installieren** (siehe oben)
2. **Dock-Icon klicken** oder **Menüleisten-🔗** → „Linky öffnen ⌘O"
3. **Browser-Fenster** öffnet sich mit Sidebar
4. **NAS hinzufügen**: Sidebar → „+ SMB-Server verbinden…" → Server eingeben → „Automatisch verbinden" aktivieren → fertig
5. **Suchen**: Tippe in das Such-Feld, schalte Scope via Pill (Ordner / Mac / NAS)
6. **Type-to-Filter**: Klick irgendwo in der Liste, fang an zu tippen → live gefiltert

## 💻 Systemanforderungen

- macOS 12 (Monterey) oder neuer
- ~5 MB Speicherplatz
- Keine zusätzlichen Abhängigkeiten

## 🔧 Berechtigungen

- **Bedienungshilfen** — Erkennen von Cmd+V
- **Mitteilungen** — Status-Benachrichtigungen
- **AppleEvents** — Öffnen von SMB-Freigaben im Finder
- **Lokales Netzwerk** — Bonjour-Discovery (wird beim ersten Browse abgefragt)

## 📝 Changelog

Siehe [CHANGELOG.md](CHANGELOG.md).

## 📄 Lizenz

MIT License — Siehe [LICENSE](LICENSE).

---

# 🔗 Linky (English)

**Linky** is a lightweight file browser for macOS with first-class SMB / NAS integration. What started as a small menu-bar utility for `smb://` links has become a fully featured Finder alternative as of v3.0.0 — with tabs, Spotlight search, NAS discovery and automatic mounting.

---

## ⚡ Install — one command

```bash
curl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash
```

> Downloads the latest release, installs to `/Applications`, removes the quarantine flag, and launches the app.

Existing installs auto-update: menu bar → **"Check for Updates…"** or on next launch.

---

## ✨ Features

### 📂 File browser
- **Browser window** with sidebar (Favorites / NAS / Devices) and file list
- **Tabs** — ⌘T new tab, ⌘W close, ⌘⇧[ / ⌘⇧] switch; each tab has its own location & history
- **Navigation** — back/forward (⌘[/⌘]), up (⌘↑), clickable breadcrumb path bar
- **Custom favorites** ★ — pin any folder/file to the sidebar, persistent
- **External devices live** — USB sticks & drives appear instantly on plug-in

### 🔍 Search
- **Three scopes** in one search:
  - **Current folder** (Spotlight, fast, focused)
  - **Whole Mac** (Spotlight, system-wide)
  - **All NAS shares** (parallel walker, streaming results) — *Spotlight doesn't index SMB, Linky does*
- **Type-to-filter (Ubuntu-style)** — just start typing while the list is focused, live-filtered view
- **Quick Look** with spacebar

### 📡 NAS / SMB (Linky's DNA)
- **Bonjour discovery** — SMB servers on your LAN appear automatically in the sidebar under "On the network", no "Connect to Server" dialog needed
- **Auto-mount** ⚡ — bookmarked shares reconnect on app launch and network change (Wi-Fi → Ethernet, VPN connect), silently when credentials are in Keychain
- **SMB bookmarks** — pin servers with a custom name, persistent across restarts
- **SMB URL handler** — `smb://` links from browser/mail open directly
- **Right-click in Finder** → "Copy SMB link" / "Open SMB link" (Quick Actions installed automatically)
- **Cmd+V auto-open** — SMB link in clipboard → opens automatically on paste

### 📁 File operations
| Action | Shortcut |
|---|---|
| Select | Click / ⌘-click / ⇧-click |
| Select all | ⌘A |
| Copy | ⌘C |
| Paste | ⌘V |
| Move | ⌥⌘V |
| Duplicate | ⌘D |
| Rename | Context menu |
| Move to trash | ⌘⌫ |
| New folder | ⇧⌘N |
| Get info | ⌘I |
| Preview | Spacebar |
| Show in Finder | Context menu |

### 🎨 Design
- **Adaptive theme** — sage / lavender / cream in light mode, copper / forest-green / charcoal in dark mode
- **Follows system appearance** automatically
- **Localized path bar** — folder names in system language (Desktop/Schreibtisch, Applications/Programme)
- **Transparent title bar** + full-size content for modern browser look

### 🖥 System integration
- **Dock icon** + **menu bar icon** in parallel — app keeps running when window is closed (auto-mount + Quick Actions stay active)
- **Autostart** optional at login
- **Auto-update** via GitHub Releases (daily check, in-app install)

## 📥 Other installation methods

### Download DMG manually
1. Download the latest [Linky-vX.X.X-macOS12+.dmg](https://github.com/Zenovs/linky/releases/latest)
2. Open the DMG and drag **Linky.app** to **Applications**
3. If a security warning appears:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Linky.app
   ```

### Build from source
See [BUILD.md](docs/BUILD.md).

## 💻 System requirements

- macOS 12 (Monterey) or newer
- ~5 MB disk space
- No additional dependencies

## 🔧 Permissions

- **Accessibility** — detect Cmd+V
- **Notifications** — status notifications
- **AppleEvents** — open SMB shares in Finder
- **Local network** — Bonjour discovery (asked on first browse)

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md).

## 📄 License

MIT License — See [LICENSE](LICENSE).
