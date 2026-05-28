"""
Linky – SMB-Link Handler für Windows
======================================
Öffnet smb:// Links direkt im Windows Explorer.

Features:
  • smb:// Protokoll-Handler (Browser, E-Mail, Teams …)
  • Zwischenablage-Monitor  – SMB-Link in Ablage → auto-öffnen
  • Explorer-Kontextmenü    – Rechtsklick → „SMB-Link kopieren"
  • Explorer-Kontextmenü    – Rechtsklick → „SMB-Link öffnen"
  • Tray-Icon mit Menü (pystray)
  • Auto-Update von GitHub
  • Autostart via Registry

Modi:
  pythonw linky.py                     → Tray-Daemon starten
  pythonw linky.py smb://…             → smb:// Link sofort öffnen
  pythonw linky.py --copy "\\path\…"  → UNC-Pfad → smb:// → Ablage
  pythonw linky.py --open "smb://…"   → smb:// Link öffnen (explizit)
"""

import sys
import os
import re
import json
import time
import threading
import subprocess
import urllib.parse
import urllib.request
import ctypes
import ctypes.wintypes
import winreg
import webbrowser
from pathlib import Path

APP_NAME    = "Linky"
APP_VERSION = "1.0.0"
GITHUB_REPO = "Zenovs/linky"
GITHUB_API  = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"

CONFIG_DIR  = Path(os.environ.get("APPDATA", Path.home())) / "Linky"
CONFIG_FILE = CONFIG_DIR / "config.json"

SMB_PATTERN = re.compile(r"^smb://[^/\s]+(?:/[^\s]*)?$", re.IGNORECASE)

# Globale Referenz auf das Tray-Icon (für Benachrichtigungen)
_icon_ref: "pystray.Icon | None" = None

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

def _load_config() -> dict:
    try:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                return json.load(f)
    except Exception:
        pass
    return {"auto_open": True, "autostart": False, "auto_update": True,
            "last_update_check": 0, "skipped_version": ""}


def _save_config(cfg: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)


_cfg = _load_config()

# ---------------------------------------------------------------------------
# Win32 Clipboard  (keine externen Abhängigkeiten)
# ---------------------------------------------------------------------------

CF_UNICODETEXT = 13
GMEM_MOVEABLE  = 0x0002

# WICHTIG: Ohne restype/argtypes nimmt ctypes 32-bit c_int an. Auf 64-bit
# Windows werden Handles/Pointer (GlobalAlloc, GlobalLock, …) dann auf 32 Bit
# abgeschnitten → defekte Handles → Clipboard schlägt fehl. Daher Prototypen:
_user32   = ctypes.windll.user32
_kernel32 = ctypes.windll.kernel32

_user32.OpenClipboard.argtypes    = [ctypes.wintypes.HWND]
_user32.OpenClipboard.restype     = ctypes.wintypes.BOOL
_user32.CloseClipboard.restype    = ctypes.wintypes.BOOL
_user32.EmptyClipboard.restype    = ctypes.wintypes.BOOL
_user32.GetClipboardData.argtypes = [ctypes.wintypes.UINT]
_user32.GetClipboardData.restype  = ctypes.wintypes.HANDLE
_user32.SetClipboardData.argtypes = [ctypes.wintypes.UINT, ctypes.wintypes.HANDLE]
_user32.SetClipboardData.restype  = ctypes.wintypes.HANDLE

_kernel32.GlobalAlloc.argtypes    = [ctypes.wintypes.UINT, ctypes.c_size_t]
_kernel32.GlobalAlloc.restype     = ctypes.wintypes.HANDLE
_kernel32.GlobalLock.argtypes     = [ctypes.wintypes.HANDLE]
_kernel32.GlobalLock.restype      = ctypes.wintypes.LPVOID
_kernel32.GlobalUnlock.argtypes   = [ctypes.wintypes.HANDLE]
_kernel32.GlobalUnlock.restype    = ctypes.wintypes.BOOL
_kernel32.GlobalFree.argtypes     = [ctypes.wintypes.HANDLE]
_kernel32.GlobalFree.restype      = ctypes.wintypes.HANDLE


def _get_clipboard_text() -> str | None:
    if not _user32.OpenClipboard(None):
        return None
    try:
        handle = _user32.GetClipboardData(CF_UNICODETEXT)
        if not handle:
            return None
        ptr = _kernel32.GlobalLock(handle)
        if not ptr:
            return None
        try:
            text = ctypes.wstring_at(ptr)
        finally:
            _kernel32.GlobalUnlock(handle)
        return text
    except Exception:
        return None
    finally:
        _user32.CloseClipboard()


def _set_clipboard_text(text: str) -> bool:
    """Schreibt Text in die Windows-Zwischenablage (CF_UNICODETEXT)."""
    data = (text + "\0").encode("utf-16-le")
    if not _user32.OpenClipboard(None):
        return False
    try:
        _user32.EmptyClipboard()
        h = _kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
        if not h:
            return False
        ptr = _kernel32.GlobalLock(h)
        if not ptr:
            _kernel32.GlobalFree(h)
            return False
        ctypes.memmove(ptr, data, len(data))
        _kernel32.GlobalUnlock(h)
        # Erfolg prüfen: bei NULL besitzen WIR den Speicher noch und müssen ihn freigeben.
        if not _user32.SetClipboardData(CF_UNICODETEXT, h):
            _kernel32.GlobalFree(h)
            return False
        # Ab hier besitzt das System den Speicher — NICHT freigeben.
        return True
    except Exception:
        return False
    finally:
        _user32.CloseClipboard()

# ---------------------------------------------------------------------------
# Pfad-Konvertierung  SMB ↔ UNC
# ---------------------------------------------------------------------------

def _is_valid_smb(url: str) -> bool:
    return bool(SMB_PATTERN.match((url or "").strip()))


def _smb_to_unc(url: str) -> str:
    """smb://server/freigabe/pfad  →  \\\\server\\freigabe\\pfad"""
    url = urllib.parse.unquote(url.strip())
    if url.lower().startswith("smb://"):
        return "\\\\" + url[6:].replace("/", "\\")
    return url


def _unc_to_smb(path: str) -> str | None:
    """\\\\server\\freigabe\\pfad  →  smb://server/freigabe/pfad"""
    path = path.strip()
    if path.startswith("\\\\"):
        return "smb://" + path[2:].replace("\\", "/")
    return None


class _UNIVERSAL_NAME_INFO(ctypes.Structure):
    # WNetGetUniversalNameW (Level 1) schreibt diese Struktur in den Buffer.
    # Das erste Feld ist ein POINTER auf den eigentlichen \\server\share-String,
    # der weiter hinten im selben Buffer liegt — NICHT der String selbst!
    _fields_ = [("lpUniversalName", ctypes.c_wchar_p)]


def _resolve_to_unc(path: str) -> str | None:
    """Löst gemappte Laufwerksbuchstaben (Z:\\) auf UNC-Pfade (\\\\server\\share) auf."""
    path = path.strip().rstrip("\\")
    if path.startswith("\\\\"):
        return path  # Bereits UNC
    if len(path) >= 2 and path[1] == ":":
        drive = path[:2].upper()      # z. B. "Z:"
        rest  = path[2:]              # Rest des Pfads nach dem Laufwerk
        try:
            UNIVERSAL_NAME_INFO_LEVEL = 1
            ERROR_MORE_DATA = 234
            buf  = ctypes.create_unicode_buffer(2048)   # 2048 wchars = 4096 Bytes
            size = ctypes.c_ulong(ctypes.sizeof(buf))
            rc = ctypes.windll.mpr.WNetGetUniversalNameW(
                ctypes.c_wchar_p(drive), UNIVERSAL_NAME_INFO_LEVEL,
                buf, ctypes.byref(size)
            )
            # Falls Buffer zu klein war: mit gemeldeter Größe erneut versuchen.
            if rc == ERROR_MORE_DATA:
                buf  = ctypes.create_unicode_buffer(size.value // 2 + 16)
                size = ctypes.c_ulong(ctypes.sizeof(buf))
                rc = ctypes.windll.mpr.WNetGetUniversalNameW(
                    ctypes.c_wchar_p(drive), UNIVERSAL_NAME_INFO_LEVEL,
                    buf, ctypes.byref(size)
                )
            if rc == 0:
                info = ctypes.cast(
                    buf, ctypes.POINTER(_UNIVERSAL_NAME_INFO)
                ).contents
                universal = info.lpUniversalName  # echter \\server\share Pfad
                if universal and universal.startswith("\\\\"):
                    return universal + rest
        except Exception:
            pass
    return None

# ---------------------------------------------------------------------------
# SMB öffnen
# ---------------------------------------------------------------------------

def _open_smb(url: str) -> None:
    unc = _smb_to_unc(url)
    # os.startfile → ShellExecute: handhabt UNC, Credentials-Dialog, Dateitypen
    try:
        os.startfile(unc)
        return
    except Exception:
        pass
    try:
        subprocess.Popen(["explorer.exe", unc])
    except Exception as e:
        _show_error(f"Fehler beim Öffnen:\n{unc}\n\n{e}")

# ---------------------------------------------------------------------------
# „SMB-Link kopieren"  (Kontextmenü-Aktion)
# ---------------------------------------------------------------------------

def _copy_smb_link(path: str) -> None:
    """Konvertiert Windows-Pfad → smb:// URL und kopiert in die Ablage."""
    unc = _resolve_to_unc(path)
    if not unc:
        _show_error(
            f"Kein Netzwerkpfad erkannt:\n{path}\n\n"
            "Nur Netzlaufwerke und UNC-Pfade (\\\\server\\...) "
            "können in SMB-Links umgewandelt werden."
        )
        return
    smb = _unc_to_smb(unc)
    if not smb:
        _show_error(f"Konvertierung fehlgeschlagen:\n{unc}")
        return
    if _set_clipboard_text(smb):
        _notify(APP_NAME, f"Kopiert: {smb}")
    else:
        _show_error(f"Zwischenablage konnte nicht beschrieben werden.\n\n{smb}")

# ---------------------------------------------------------------------------
# Zwischenablage-Monitor  (Clipboard-Sequenznummer, kein Polling-Overhead)
# ---------------------------------------------------------------------------

def _start_clipboard_monitor() -> None:
    """Überwacht die Zwischenablage auf smb:// Links und öffnet sie automatisch."""
    last_seq = [ctypes.windll.user32.GetClipboardSequenceNumber()]

    def _poll() -> None:
        while True:
            try:
                seq = ctypes.windll.user32.GetClipboardSequenceNumber()
                if seq != last_seq[0]:
                    last_seq[0] = seq
                    text = _get_clipboard_text()
                    if text:
                        text = text.strip()
                        if _cfg.get("auto_open", True) and _is_valid_smb(text):
                            _notify(APP_NAME, "SMB-Link wird geöffnet…")
                            _open_smb(text)
            except Exception:
                pass
            time.sleep(0.8)

    threading.Thread(target=_poll, daemon=True, name="ClipboardMonitor").start()

# ---------------------------------------------------------------------------
# Benachrichtigungen
# ---------------------------------------------------------------------------

def _notify(title: str, message: str) -> None:
    """Benachrichtigung via Tray-Icon (pystray) oder MessageBox-Fallback."""
    global _icon_ref
    try:
        if _icon_ref is not None:
            _icon_ref.notify(message, title)
            return
    except Exception:
        pass
    # Fallback wenn kein Tray läuft (z. B. --copy / --open Modus)
    try:
        ctypes.windll.user32.MessageBoxW(0, message, title, 0x40)  # MB_ICONINFORMATION
    except Exception:
        pass


def _show_error(msg: str) -> None:
    try:
        ctypes.windll.user32.MessageBoxW(0, msg, APP_NAME, 0x10)
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Auto-Update von GitHub
# ---------------------------------------------------------------------------

UPDATE_INTERVAL = 24 * 60 * 60  # Sekunden


def _version_tuple(v: str):
    try:
        return tuple(int(x) for x in v.strip().lstrip("v").split("."))
    except Exception:
        return (0,)


def _is_newer(remote: str, local: str) -> bool:
    return _version_tuple(remote) > _version_tuple(local)


def _check_updates(manual: bool = False) -> None:
    def _worker() -> None:
        release_url = f"https://github.com/{GITHUB_REPO}/releases/latest"
        try:
            req = urllib.request.Request(
                GITHUB_API,
                headers={"User-Agent": f"{APP_NAME}/{APP_VERSION}"}
            )
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.loads(r.read())

            remote   = data.get("tag_name", "").lstrip("v")
            release_url = data.get("html_url", release_url)
            assets   = data.get("assets", [])

            _cfg["last_update_check"] = int(time.time())
            _save_config(_cfg)

            # Nur Windows-Releases anzeigen (nicht macOS DMGs).
            # GitHub-Releases sind aktuell macOS-only. Automatischer Check
            # feuert nur wenn ein Windows-Asset (.exe / .msi / windows*.zip) existiert.
            has_windows_asset = any(
                "windows" in a.get("name", "").lower() or
                a.get("name", "").lower().endswith((".exe", ".msi"))
                for a in assets
            )

            skipped = _cfg.get("skipped_version", "")

            if manual:
                # Manuell: immer Feedback geben, GitHub-Seite anbieten
                IDYES = 6
                if has_windows_asset and _is_newer(remote, APP_VERSION) and remote != skipped:
                    msg = (
                        f"{APP_NAME} {remote} ist verfügbar!\n"
                        f"Installierte Version: {APP_VERSION}\n\n"
                        "GitHub öffnen und aktualisieren?"
                    )
                else:
                    msg = (
                        f"Installierte Version: {APP_VERSION}\n"
                        f"Aktuelle GitHub-Version: {remote}\n\n"
                        "GitHub-Releases öffnen?"
                    )
                result = ctypes.windll.user32.MessageBoxW(
                    0, msg, f"{APP_NAME} – Updates", 0x24  # MB_YESNO
                )
                if result == IDYES:
                    webbrowser.open(release_url)
            else:
                # Automatisch: nur bei Windows-Asset und neuer Version
                if has_windows_asset and _is_newer(remote, APP_VERSION) and remote != skipped:
                    _show_update_dialog(remote, release_url)

        except Exception as e:
            if manual:
                _show_error(f"Update-Prüfung fehlgeschlagen:\n{e}")

    threading.Thread(target=_worker, daemon=True, name="UpdateCheck").start()


def _show_update_dialog(version: str, url: str) -> None:
    IDYES = 6
    msg = (
        f"{APP_NAME} {version} ist verfügbar!\n"
        f"Installierte Version: {APP_VERSION}\n\n"
        "GitHub öffnen und aktualisieren?"
    )
    result = ctypes.windll.user32.MessageBoxW(
        0, msg, f"{APP_NAME} – Update verfügbar", 0x24  # MB_YESNO | MB_ICONQUESTION
    )
    if result == IDYES:
        webbrowser.open(url)
    else:
        _cfg["skipped_version"] = version
        _save_config(_cfg)


def _schedule_update_check() -> None:
    """Prüft alle 6 Stunden ob ein Update-Check fällig ist (max 1× pro 24h)."""
    def _loop() -> None:
        while True:
            time.sleep(6 * 3600)
            if not _cfg.get("auto_update", True):
                continue
            last = _cfg.get("last_update_check", 0)
            if time.time() - last >= UPDATE_INTERVAL:
                _check_updates(manual=False)

    threading.Thread(target=_loop, daemon=True, name="UpdateTimer").start()

# ---------------------------------------------------------------------------
# Autostart  (Registry Run-Key)
# ---------------------------------------------------------------------------

_REG_RUN = r"Software\Microsoft\Windows\CurrentVersion\Run"
_PYTHONW  = Path(sys.executable).parent / "pythonw.exe"
_THIS     = Path(sys.argv[0]).resolve()


def _set_autostart(enabled: bool) -> None:
    _cfg["autostart"] = enabled
    _save_config(_cfg)
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_RUN, 0, winreg.KEY_SET_VALUE)
    try:
        if enabled:
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ,
                              f'"{_PYTHONW}" "{_THIS}"')
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except FileNotFoundError:
                pass
    finally:
        key.Close()

# ---------------------------------------------------------------------------
# Konsole verstecken
# ---------------------------------------------------------------------------

def _hide_console() -> None:
    try:
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()
        if hwnd:
            ctypes.windll.user32.ShowWindow(hwnd, 0)
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Tray-Icon erstellen
# ---------------------------------------------------------------------------

def _make_icon_image():
    from PIL import Image, ImageDraw
    size = 64
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d    = ImageDraw.Draw(img)
    d.ellipse([1, 1, size - 2, size - 2], fill=(52, 120, 246, 255))
    ring_w = 5
    for x0, x1 in [(6, 34), (30, 58)]:
        d.ellipse([x0, 18, x1, 46], fill="white")
        d.ellipse([x0 + ring_w, 18 + ring_w, x1 - ring_w, 46 - ring_w],
                  fill=(52, 120, 246, 255))
    d.rectangle([20, 26, 44, 38], fill="white")
    d.rectangle([26, 28, 38, 36], fill=(52, 120, 246, 255))
    return img

# ---------------------------------------------------------------------------
# Tray-Daemon
# ---------------------------------------------------------------------------

def _run_tray() -> None:
    global _icon_ref
    _hide_console()

    try:
        import pystray
        from PIL import Image
    except ImportError as e:
        _show_error(
            "pystray / Pillow nicht installiert.\n\n"
            "Bitte in der Eingabeaufforderung ausführen:\n"
            "  pip install pystray Pillow\n\n"
            f"Fehler: {e}"
        )
        return

    icon_img = _make_icon_image()

    # ── Menü-Callbacks ───────────────────────────────────────────────────────

    def _auto_open_checked(item):   return bool(_cfg.get("auto_open",   True))
    def _autostart_checked(item):   return bool(_cfg.get("autostart",   False))
    def _auto_update_checked(item): return bool(_cfg.get("auto_update", True))

    def _toggle_auto_open(icon, item):
        _cfg["auto_open"] = not _cfg.get("auto_open", True)
        _save_config(_cfg)
        icon.update_menu()

    def _toggle_autostart(icon, item):
        new_val = not _cfg.get("autostart", False)
        try:
            _set_autostart(new_val)
        except Exception as e:
            _show_error(f"Autostart konnte nicht gesetzt werden:\n{e}")
            return
        icon.update_menu()

    def _toggle_auto_update(icon, item):
        _cfg["auto_update"] = not _cfg.get("auto_update", True)
        _save_config(_cfg)
        icon.update_menu()

    def _manual_update(icon, item):
        _check_updates(manual=True)

    def _open_github(icon, item):
        webbrowser.open(f"https://github.com/{GITHUB_REPO}")

    def _quit(icon, item):
        icon.stop()

    # ── Menü aufbauen ────────────────────────────────────────────────────────

    menu = pystray.Menu(
        pystray.MenuItem(f"{APP_NAME} v{APP_VERSION}", None, enabled=False),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Automatisch öffnen", _toggle_auto_open,
                         checked=_auto_open_checked),
        pystray.MenuItem("Autostart aktivieren", _toggle_autostart,
                         checked=_autostart_checked),
        pystray.MenuItem("Auto-Update aktivieren", _toggle_auto_update,
                         checked=_auto_update_checked),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Nach Updates suchen…", _manual_update),
        pystray.MenuItem("GitHub öffnen",         _open_github),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Beenden", _quit),
    )

    icon = pystray.Icon(APP_NAME, icon_img, APP_NAME, menu)
    _icon_ref = icon

    # ── Hintergrundaufgaben starten ──────────────────────────────────────────
    _start_clipboard_monitor()

    if _cfg.get("auto_update", True):
        last = _cfg.get("last_update_check", 0)
        if time.time() - last >= UPDATE_INTERVAL:
            _check_updates(manual=False)
    _schedule_update_check()

    icon.run()

# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    args = sys.argv[1:]

    if not args:
        # Tray-Daemon
        _run_tray()

    elif args[0] == "--copy" and len(args) >= 2:
        # Rechtsklick „SMB-Link kopieren"  →  UNC → smb:// → Ablage
        _copy_smb_link(args[1])

    elif args[0] == "--open" and len(args) >= 2:
        # Rechtsklick „SMB-Link öffnen"
        url = args[1]
        if _is_valid_smb(url):
            _open_smb(url)
        else:
            _show_error(f"Kein gültiger SMB-Link:\n{url}")

    else:
        # Browser / Protokoll-Handler: linky.py smb://…
        url = args[0]
        if _cfg.get("auto_open", True) and _is_valid_smb(url):
            _open_smb(url)
