# Mitwirken an Linky

Vielen Dank für dein Interesse an Linky! 🎉

## Wie kann ich beitragen?

### 🐛 Fehler melden

1. Überprüfe zuerst die [Issues](https://github.com/Zenovs/linky/issues), ob der Fehler bereits gemeldet wurde
2. Erstelle ein neues Issue mit:
   - Klarer Beschreibung des Problems
   - Schritten zur Reproduktion
   - Erwartetes vs. tatsächliches Verhalten
   - macOS-Version und Linky-Version
   - Screenshots falls hilfreich

### 💡 Neue Funktionen vorschlagen

1. Öffne ein [Feature Request Issue](https://github.com/Zenovs/linky/issues/new?template=feature_request.md)
2. Beschreibe:
   - Was soll die Funktion tun?
   - Warum wäre sie nützlich?
   - Wie könnte sie implementiert werden?

### 🔧 Code beitragen

1. **Fork** das Repository
2. Erstelle einen **Feature-Branch**: `git checkout -b feature/meine-funktion`
3. **Committe** deine Änderungen: `git commit -m 'Add: Meine neue Funktion'`
4. **Push** zum Branch: `git push origin feature/meine-funktion`
5. Öffne einen **Pull Request**

## Entwicklungsumgebung

### Voraussetzungen
- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)
- Für Python-Version: Python 3.9+

### Setup

```bash
# Repository klonen
git clone https://github.com/Zenovs/linky.git
cd linky

# Für Python-Version
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Für Swift-Version
./build_scripts/build_swift.sh
```

## Code-Stil

### Python
- PEP 8 befolgen
- Docstrings für alle öffentlichen Funktionen
- Type Hints wo möglich

### Swift
- Swift API Design Guidelines befolgen
- `// MARK:` für Code-Abschnitte verwenden
- Dokumentationskommentare mit `///`

## Commit-Nachrichten

Format: `<Typ>: <Beschreibung>`

- `Add:` Neue Funktion
- `Fix:` Bugfix
- `Update:` Aktualisierung
- `Docs:` Dokumentation
- `Refactor:` Code-Refactoring
- `Test:` Tests

## Pull Request Prozess

1. Stelle sicher, dass dein Code kompiliert
2. Aktualisiere die README/Docs falls nötig
3. Füge CHANGELOG.md Eintrag hinzu
4. Warte auf Code-Review

## Verhaltenskodex

- Sei respektvoll und konstruktiv
- Keine Diskriminierung
- Fokus auf sachliche Diskussionen

---

Vielen Dank für deine Beiträge! 🙏
