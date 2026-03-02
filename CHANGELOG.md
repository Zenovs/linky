# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt hält sich an [Semantic Versioning](https://semver.org/lang/de/).

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
