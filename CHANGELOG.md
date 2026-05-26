# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

---

## [3.0.2] - 2026-05-26

### Behoben
- 🔍 **NAS-Suche findet jetzt zuverlässig** — Walker war Depth-First (FileManager.enumerator) und vergrub sich in der ersten Unterordner-Hierarchie. Auf großen SMB-Shares wurde so der erste relevante Top-Level-Eintrag nach 30 s noch nicht erreicht. Umgebaut auf **Breadth-First** mit `contentsOfDirectory` pro Level — shallow Treffer erscheinen in Sekunden
- ⏱ Hard-Timeout von 60 s pro Volume, max. Tiefe 12 Levels, Bundle-Ordner (.app/.bundle/.framework/.photoslibrary/.musiclibrary) werden übersprungen — sauberer Abbruch statt endlosem Walk

### Verbessert
- 🎯 **NAS-Volume-Erkennung robuster** — Fallback wenn `volumeIsLocal` nicht korrekt gesetzt ist (manche SMB-Server liefern das nicht); jeder Non-Internal-Mount unter `/Volumes/` zählt als suchbar
- 🇩🇪 **Diakritik-tolerante Suche** — „muller" findet „Müller", „cafe" findet „Café"
- 🗂 **„Ordner"-Scope nutzt automatisch den Walker** wenn du im NAS-Pfad stehst (Spotlight indiziert SMB nicht)

---

## [3.0.1] - 2026-05-26

### Behoben
- 🐛 **Linky hängt sich beim Klick auf SMB-Bookmark auf** — `handleSidebarSelection` versuchte `FileManager.contentsOfDirectory` auf rohen `smb://`-URLs, was die I/O-Queue blockierte wenn der Share noch nicht gemountet war. Jetzt wird vorher geprüft ob der Share schon gemountet ist (→ Navigation zum lokalen Mount-Point) oder ob ein Mount getriggert werden muss
- 🛡️ **Defensive Guard** in `TabModel.loadContents()` gegen Non-File-URLs — sofortiger Abbruch mit leerer Liste statt blockierender Enumeration

---

## [3.0.0] - 2026-05-25

### Major — Vom SMB-Helfer zum vollwertigen Datei-Browser

Linky ist nicht mehr nur eine Menüleisten-Utility — die App öffnet jetzt ein eigenes Browser-Fenster mit Sidebar, Datei-Liste und integrierter Suche. Alle bisherigen Funktionen (SMB-Auto-Open, Quick Actions, Browser-Dienst) bleiben unverändert.

### Hinzugefügt
- 🪟 **Datei-Browser-Fenster** mit Sidebar (Favoriten / NAS / Geräte) + Datei-Liste mit Spalten Name/Geändert/Größe
- 🔍 **Suche** mit drei Scopes: aktueller Ordner, ganzer Mac (Spotlight), alle gemounteten NAS-Shares (paralleler Walker)
- 📑 **Tabs** — ⌘T neuer Tab, ⌘W schliessen, ⌘⇧[ / ⌘⇧] wechseln, jeder Tab hat eigene Location & History
- ⭐ **Eigene Favoriten** — Datei oder Ordner zu Sidebar pinnen, persistent
- 📡 **Bonjour-SMB-Discovery** — SMB-Server im LAN erscheinen automatisch in der Sidebar unter „Im Netzwerk"
- ⚡ **Auto-Mount für SMB-Verknüpfungen** beim App-Start und bei Netzwerk-Wechsel (Wi-Fi / Ethernet / VPN), via `NWPathMonitor`
- 📁 **Datei-Operationen** — Kopieren (⌘C), Einfügen (⌘V), Verschieben (⌥⌘V), Duplizieren (⌘D), Umbenennen, In Papierkorb (⌘⌫), Neuer Ordner (⇧⌘N), Information (⌘I), Quick Look (Leertaste), Alle auswählen (⌘A)
- 🔤 **Type-to-Filter à la Ubuntu** — einfach lostippen während die Liste sichtbar ist, lokal gefilterte Ansicht mit Floating-Badge
- 🗺️ **Lokalisierte Pfadleiste & Sidebar** — Ordnernamen folgen der System-Sprache (Dokumente / Documents, Programme / Applications)
- 🎨 **Adaptives Design-System** — Sage-Grün / Lavendel / Crème im Light Mode, Kupfer / Forest-Green / Charcoal im Dark Mode, folgt automatisch der System-Einstellung
- 🅻 **LINKY ASCII-Logo** oben links in der Sidebar
- 🟢 **Dock-Icon** — App ist jetzt sowohl im Dock als auch in der Menüleiste, kann via Rechtsklick fixiert werden
- 🗂 **Programme-Ansicht zusammengeführt** — `/Applications` + `/System/Applications` werden gemeinsam angezeigt
- 🚀 **Apps starten beim Doppelklick** statt Paketinhalt zu zeigen

### Geändert
- 🔄 **Bundle-Struktur**: alle bisherigen Features bleiben, ergänzt um umfangreiche neue Module (BrowserWindow, Sidebar, FileListView, SearchEngine, VolumeManager, FavoriteStore, BonjourBrowser, AutoMountService, TabManager, QuickLookHandler, Theme)
- 🔄 **LSUIElement** entfernt — App ist jetzt Regular statt Accessory, startet mit Dock-Icon
- 🔄 **Title-Bar transparent** mit Full-Size-Content für moderne Browser-Optik

### Behoben
- 🐛 Selektion in Datei-Liste wird jetzt zuverlässig sichtbar gerendert (statt unsichtbar zu bleiben)
- 🐛 System-Beep beim Tippen unterdrückt — Type-to-Filter ist geräuschlos
- 🐛 Breadcrumb-Höhe auf 24pt fixiert (vorher hat horizontaler ScrollView vertikal expandiert)

---

## [2.1.0] - 2026-03-18

### Hinzugefügt
- 🆕 **Automatische Workflow-Installation**: Der Finder Quick Action "SMB-Link kopieren" wird beim ersten App-Start automatisch in `~/Library/Services/` installiert – kein manuelles Drag & Drop mehr nötig

### Verbessert
- ✨ DMG enthält nur noch die App (kein separater Workflow-Schritt)
- ✨ Installation vereinfacht: Download → App in Programme → Starten – fertig

---

## [2.0.0] - 2026-03-02

### Hinzugefügt
- 🆕 **Auto-Update-Funktion**: Automatische Prüfung auf neue GitHub-Releases
- 🆕 **Update-Benachrichtigungen**: macOS-Benachrichtigungen bei verfügbaren Updates
- 🆕 **Menü-Eintrag**: "Nach Updates suchen..." im Menü
- 🆕 **Einstellung**: Toggle für automatische Update-Prüfung
- 🆕 **Versionsnummer**: Semantic Versioning (2.0.0)

### Geändert
- 🔄 **Umbenennung**: "SMB Link Manager" zu "Linky"
- 🔄 **Bundle ID**: Geändert zu `com.linky.app`
- 🔄 **Launch Agent**: Geändert zu `com.linky.autostart`
- 🔄 **Code-Struktur**: Verbesserte Modularisierung

### Verbessert
- ✨ GitHub-Repository-Struktur mit vollständiger Dokumentation
- ✨ Verbesserte Fehlerbehandlung bei Update-Prüfung
- ✨ Version-Vergleich mit Semantic Versioning

---

## [1.0.0] - 2024-XX-XX

### Hinzugefügt
- 🎉 **Erste Veröffentlichung**
- Menu Bar Integration
- SMB-Link kopieren Workflow (Finder Quick Action)
- Automatisches Öffnen von SMB-Links
- Autostart-Option (Launch Agent)
- macOS-Benachrichtigungen
- Python/PyObjC und Swift Implementierungen

---

## Versionsschema

Dieses Projekt verwendet [Semantic Versioning](https://semver.org/lang/de/):

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Funktionen (abwärtskompatibel)
- **PATCH**: Bugfixes (abwärtskompatibel)

Beispiele:
- `2.0.0` → `2.0.1`: Bugfix
- `2.0.0` → `2.1.0`: Neue Funktion
- `2.0.0` → `3.0.0`: Große Änderungen
