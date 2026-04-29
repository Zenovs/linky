"""
Linky – SMB-Link Handler für Windows
======================================
Wandelt smb://server/freigabe/pfad in \\\\server\\freigabe\\pfad um
und öffnet den Pfad direkt im Windows Explorer.

Modi:
  pythonw linky.py                → Tray-Daemon starten
  pythonw linky.py smb://…       → Link sofort öffnen (aufgerufen vom Browser)
"""

import sys
import os
import json
import subprocess
import urllib.parse
import winreg
from pathlib import Path

APP_NAME    = "Linky"
APP_VERSION = "1.0.0"
GITHUB_REPO = "Zenovs/linky"

CONFIG_DIR  = Path(os.environ.get("APPDATA", Path.home())) / "Linky"
CONFIG_FILE = CONFIG_DIR / "config.json"

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
    return {"auto_open": True, "autostart": False}


def _save_config(cfg: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f, indent=2)


_cfg = _load_config()

# ---------------------------------------------------------------------------
# SMB → UNC → Explorer
# ---------------------------------------------------------------------------

def _smb_to_unc(url: str) -> str:
    """smb://server/freigabe/pfad  →  \\\\server\\freigabe\\pfad"""
    url = urllib.parse.unquote(url.strip())
    if url.lower().startswith("smb://"):
        path = url[6:].replace("/", "\\")
        return "\\\\" + path
    return url


def _open_smb(url: str) -> None:
    unc = _smb_to_unc(url)
    # os.startfile → ShellExecute: handhabt UNC, Credentials-Dialog und Dateitypen
    try:
        os.startfile(unc)
        return
    except Exception:
        pass
    # Fallback: Explorer direkt
    try:
        subprocess.Popen(["explorer.exe", unc])
    except Exception as e:
        _show_error(f"Fehler beim Öffnen von {unc}:\n{e}")


# ---------------------------------------------------------------------------
# Tray-Icon Icon
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
# Autostart  (Registry Run-Key)
# ---------------------------------------------------------------------------

_REG_RUN = r"Software\Microsoft\Windows\CurrentVersion\Run"
_PYTHONW  = Path(sys.executable).parent / "pythonw.exe"
_THIS     = Path(sys.argv[0]).resolve()


def _set_autostart(enabled: bool) -> None:
    _cfg["autostart"] = enabled
    _save_config(_cfg)

    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_RUN, 0,
                         winreg.KEY_SET_VALUE)
    try:
        if enabled:
            cmd = f'"{_PYTHONW}" "{_THIS}"'
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, cmd)
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except FileNotFoundError:
                pass
    finally:
        key.Close()


# ---------------------------------------------------------------------------
# Fehler-Dialog (kein Tray nötig)
# ---------------------------------------------------------------------------

def _show_error(msg: str) -> None:
    try:
        import ctypes
        ctypes.windll.user32.MessageBoxW(0, msg, APP_NAME, 0x10)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Konsole verstecken (wenn als .pyw / pythonw gestartet)
# ---------------------------------------------------------------------------

def _hide_console() -> None:
    try:
        import ctypes
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()
        if hwnd:
            ctypes.windll.user32.ShowWindow(hwnd, 0)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Tray-Daemon
# ---------------------------------------------------------------------------

def _run_tray() -> None:
    _hide_console()

    try:
        import pystray
        from PIL import Image
    except ImportError as e:
        _show_error(
            f"pystray / Pillow nicht installiert.\n\n"
            f"Bitte in der Eingabeaufforderung ausführen:\n"
            f"  pip install pystray Pillow\n\n{e}"
        )
        return

    icon_img = _make_icon_image()

    def _auto_open_checked(item):
        return _cfg.get("auto_open", True)

    def _autostart_checked(item):
        return _cfg.get("autostart", False)

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

    def _open_github(icon, item):
        import webbrowser
        webbrowser.open(f"https://github.com/{GITHUB_REPO}")

    def _quit(icon, item):
        icon.stop()

    menu = pystray.Menu(
        pystray.MenuItem(f"{APP_NAME} v{APP_VERSION}", None, enabled=False),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Automatisch öffnen", _toggle_auto_open,
                         checked=_auto_open_checked),
        pystray.MenuItem("Autostart aktivieren", _toggle_autostart,
                         checked=_autostart_checked),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("GitHub öffnen", _open_github),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Beenden", _quit),
    )

    icon = pystray.Icon(APP_NAME, icon_img, APP_NAME, menu)
    icon.run()


# ---------------------------------------------------------------------------
# Einstiegspunkt
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) > 1:
        url = sys.argv[1]
        if _cfg.get("auto_open", True) and url.lower().startswith("smb://"):
            _open_smb(url)
    else:
        _run_tray()
