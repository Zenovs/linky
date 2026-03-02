# Linky v2.0.1 - Test-Checkliste

## 📋 Übersicht
Diese Checkliste hilft beim systematischen Testen von Linky auf macOS.

---

## ✅ Basis-Tests

### 1. Installation
- [ ] DMG lässt sich öffnen
- [ ] App lässt sich in Programme-Ordner ziehen
- [ ] Workflow lässt sich per Doppelklick installieren

### 2. Erster Start
- [ ] App startet ohne Absturz
- [ ] Sicherheitsdialog erscheint (falls nicht signiert)
- [ ] "Trotzdem öffnen" funktioniert
- [ ] PyObjC-Check funktioniert
- [ ] Installationsdialog erscheint (falls PyObjC fehlt)

### 3. Menüleiste
- [ ] Symbol (🔗) erscheint in Menüleiste
- [ ] Klick auf Symbol öffnet Dropdown-Menü
- [ ] Alle Menüpunkte werden angezeigt:
  - [ ] Automatisches Öffnen
  - [ ] Bei Anmeldung starten
  - [ ] Automatisch nach Updates suchen
  - [ ] Nach Updates suchen...
  - [ ] Über Linky
  - [ ] Beenden

---

## ✅ Funktions-Tests

### 4. Automatisches Öffnen (Cmd+V)
- [ ] SMB-Link kopieren: `smb://server/freigabe/ordner`
- [ ] Cmd+V drücken
- [ ] Finder öffnet SMB-Pfad
- [ ] Benachrichtigung erscheint

### 5. Workflow (Rechtsklick-Menü)
- [ ] Workflow ist in Schnellaktionen sichtbar
- [ ] Rechtsklick auf Ordner → "SMB-Link kopieren"
- [ ] SMB-Link wird in Zwischenablage kopiert
- [ ] Format korrekt: `smb://computername/freigabe/pfad`

### 6. Einstellungen
- [ ] "Automatisches Öffnen" umschalten → Einstellung wird gespeichert
- [ ] "Bei Anmeldung starten" → LaunchAgent wird erstellt
- [ ] "Auto-Update" umschalten → Einstellung wird gespeichert

### 7. Auto-Update
- [ ] "Nach Updates suchen..." klicken
- [ ] Benachrichtigung erscheint ("Suche nach Updates...")
- [ ] Ergebnis wird angezeigt (Update verfügbar / aktuell)

### 8. Über-Dialog
- [ ] "Über Linky" zeigt Dialog mit Versionsnummer
- [ ] GitHub-Link funktioniert

---

## ✅ Edge-Cases

### 9. Fehlerbehandlung
- [ ] Ungültiger SMB-Link wird ignoriert
- [ ] Nicht erreichbarer Server zeigt Finder-Fehler
- [ ] App stürzt nicht ab bei Fehlern

### 10. Berechtigungen
- [ ] App fragt nach Bedienungshilfen-Zugriff
- [ ] App funktioniert nach Berechtigung korrekt
- [ ] App funktioniert eingeschränkt ohne Berechtigung

---

## 📝 Test-Ergebnisse

### Getestet auf:
- macOS Version: _______________
- Mac-Modell: _______________
- Python-Version: _______________
- Datum: _______________

### Ergebnis:
- [ ] Alle Tests bestanden
- [ ] Einige Tests fehlgeschlagen (siehe unten)

### Gefundene Probleme:
```
(Hier Probleme dokumentieren)
```

---

## 🐛 Fehler melden

1. **GitHub Issues:** https://github.com/Zenovs/linky/issues

2. **Benötigte Informationen:**
   - macOS-Version
   - Fehlerbeschreibung
   - Schritte zum Reproduzieren
   - Log-Datei: `~/Library/Logs/Linky.log`

3. **Log-Datei finden:**
   ```bash
   open ~/Library/Logs/Linky.log
   ```

---

## 🔧 Schnelle Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| App startet nicht | Rechtsklick → Öffnen, oder Systemeinstellungen → Sicherheit |
| PyObjC fehlt | `pip3 install pyobjc` im Terminal |
| Cmd+V funktioniert nicht | Bedienungshilfen-Berechtigung erteilen |
| Symbol nicht sichtbar | App beenden und neu starten |
| Workflow nicht sichtbar | Workflow erneut installieren |

---

*Linky v2.0.1 - Test-Version*
