#!/usr/bin/env python3
"""
Linky – SMB-Link Handler für Linux
====================================
Läuft als Systemtray-Daemon und öffnet smb:// Links automatisch
im installierten Dateimanager (Nautilus, Dolphin, Thunar, …).

Modi:
  linky                  → Tray-Daemon starten
  linky smb://server/…   → Link sofort öffnen (aufgerufen vom Browser)
"""

import sys
import os
import json
import signal
import subprocess
import urllib.parse
import threading
from pathlib import Path

APP_NAME    = "Linky"
APP_VERSION = "1.0.0"
GITHUB_REPO = "Zenovs/linky"

CONFIG_DIR  = Path.home() / ".config" / "linky"
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
# SMB öffnen
# ---------------------------------------------------------------------------

def _open_smb(url: str) -> None:
    url = urllib.parse.unquote(url.strip())
    if not url.lower().startswith("smb://"):
        return

    # Versuche Dateimanager in Reihenfolge
    for cmd in [
        ["xdg-open", url],
        ["gio", "open", url],
        ["nautilus", "--no-desktop", url],
        ["dolphin", url],
        ["thunar", url],
        ["nemo", url],
        ["pcmanfm", url],
    ]:
        try:
            subprocess.Popen(cmd, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
            return
        except FileNotFoundError:
            continue

    # Letzter Ausweg: notify-send
    _notify("Kein Dateimanager gefunden", f"Bitte manuell öffnen: {url}")


# ---------------------------------------------------------------------------
# Benachrichtigung
# ---------------------------------------------------------------------------

def _notify(title: str, body: str) -> None:
    try:
        subprocess.Popen(
            ["notify-send", "-a", APP_NAME, "-i", "folder-network", title, body],
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


# ---------------------------------------------------------------------------
# Autostart  (~/.config/autostart/linky.desktop)
# ---------------------------------------------------------------------------

_AUTOSTART_FILE = Path.home() / ".config" / "autostart" / "linky.desktop"
_BINARY         = Path.home() / ".local" / "bin" / "linky"


def _set_autostart(enabled: bool) -> None:
    _cfg["autostart"] = enabled
    _save_config(_cfg)

    dest = _AUTOSTART_FILE
    dest.parent.mkdir(parents=True, exist_ok=True)

    if enabled:
        dest.write_text(
            "[Desktop Entry]\n"
            f"Name={APP_NAME}\n"
            "Comment=SMB-Link Handler\n"
            f"Exec={_BINARY}\n"
            "Type=Application\n"
            "Hidden=false\n"
            "X-GNOME-Autostart-enabled=true\n"
        )
    else:
        dest.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Tray-Icon  (benötigt pystray + Pillow)
# ---------------------------------------------------------------------------

def _make_icon_image():
    from PIL import Image, ImageDraw

    size = 64
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d    = ImageDraw.Draw(img)

    # Blauer Kreis
    d.ellipse([1, 1, size - 2, size - 2], fill=(52, 120, 246, 255))

    # Zwei weiße Ringe → Kettenglied
    ring_w = 5
    for x0, x1 in [(6, 34), (30, 58)]:
        d.ellipse([x0, 18, x1, 46], fill="white")
        d.ellipse([x0 + ring_w, 18 + ring_w, x1 - ring_w, 46 - ring_w],
                  fill=(52, 120, 246, 255))

    # Verbinder in der Mitte
    d.rectangle([20, 26, 44, 38], fill="white")
    d.rectangle([26, 28, 38, 36], fill=(52, 120, 246, 255))

    return img


def _run_tray() -> None:
    try:
        import pystray
        from PIL import Image
    except ImportError:
        print(f"{APP_NAME}: pystray/Pillow nicht verfügbar – läuft ohne Tray-Icon.")
        # Blockiere trotzdem (Handler-Modus braucht keinen Daemon)
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
        signal.pause()
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
        _set_autostart(new_val)
        icon.update_menu()

    def _open_github(icon, item):
        subprocess.Popen(["xdg-open", f"https://github.com/{GITHUB_REPO}"],
                         stderr=subprocess.DEVNULL)

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
        # Aufgerufen vom Browser/DE als Protokoll-Handler
        url = sys.argv[1]
        if _cfg.get("auto_open", True) and url.lower().startswith("smb://"):
            _notify(APP_NAME, "SMB-Link wird geöffnet…")
            _open_smb(url)
    else:
        # Daemon mit Tray-Icon
        _run_tray()
