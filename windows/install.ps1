#Requires -Version 5.1
<#
.SYNOPSIS
    Linky – Windows Installer
.DESCRIPTION
    Installiert Linky als smb:// Protokoll-Handler.
    Ausführen mit:
        powershell -ExecutionPolicy Bypass -File install.ps1
#>

$ErrorActionPreference = "Stop"

$AppName    = "Linky"
$GithubRepo = "Zenovs/linky"
$InstallDir = "$env:LOCALAPPDATA\Linky"
$ScriptDest = "$InstallDir\linky.py"

# ── Farben-Helfer ─────────────────────────────────────────────────────────────
function Step($msg)  { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "  ✔  $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "`n  ✖  $msg`n" -ForegroundColor Red; exit 1 }

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ██╗     ██╗███╗   ██╗██╗  ██╗██╗   ██╗" -ForegroundColor Cyan
Write-Host "  ██║     ██║████╗  ██║██║ ██╔╝╚██╗ ██╔╝" -ForegroundColor Cyan
Write-Host "  ██║     ██║██╔██╗ ██║█████╔╝  ╚████╔╝ " -ForegroundColor Cyan
Write-Host "  ██║     ██║██║╚██╗██║██╔═██╗   ╚██╔╝  " -ForegroundColor Cyan
Write-Host "  ███████╗██║██║ ╚████║██║  ██╗   ██║   " -ForegroundColor Cyan
Write-Host "  ╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝  " -ForegroundColor Cyan
Write-Host ""
Write-Host "  SMB-Link Handler für Windows" -ForegroundColor DarkGray
Write-Host ""

# ── 1. Python prüfen ──────────────────────────────────────────────────────────
Step "Python prüfen"

$python    = $null
$pythonw   = $null

# Versuche python, python3, py (Windows Launcher)
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python 3") {
            $python  = (Get-Command $cmd -ErrorAction SilentlyContinue).Source
            # pythonw.exe liegt im selben Verzeichnis wie python.exe
            $pythonw = Join-Path (Split-Path $python) "pythonw.exe"
            if (-not (Test-Path $pythonw)) { $pythonw = $python }
            Ok "$ver  ($python)"
            break
        }
    } catch { }
}

if (-not $python) {
    Warn "Python 3 nicht gefunden."
    Write-Host ""
    Write-Host "  Bitte Python 3 installieren:" -ForegroundColor Yellow
    Write-Host "  https://www.python.org/downloads/" -ForegroundColor White
    Write-Host "  (Haken setzen bei 'Add Python to PATH')" -ForegroundColor White
    Write-Host ""
    $open = Read-Host "  Jetzt python.org öffnen? [J/n]"
    if ($open -ne "n" -and $open -ne "N") {
        Start-Process "https://www.python.org/downloads/"
    }
    Fail "Python 3 wird benötigt."
}

# ── 2. Skript installieren ────────────────────────────────────────────────────
Step "Linky installieren"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$localScript = Join-Path $PSScriptRoot "linky.py"
if (Test-Path $localScript) {
    Copy-Item $localScript $ScriptDest -Force
    Ok "Skript lokal kopiert"
} else {
    Write-Host "  Lade linky.py von GitHub…" -NoNewline
    $url = "https://raw.githubusercontent.com/$GithubRepo/main/windows/linky.py"
    try {
        Invoke-WebRequest -Uri $url -OutFile $ScriptDest -UseBasicParsing
        Write-Host " ✔" -ForegroundColor Green
    } catch {
        Fail "Download fehlgeschlagen: $_"
    }
}

Ok "Installiert: $ScriptDest"

# ── 3. pip-Pakete ─────────────────────────────────────────────────────────────
Step "Python-Pakete installieren (pystray + Pillow)"

try {
    & $python -m pip install --quiet --user pystray Pillow 2>&1 | Out-Null
    Ok "pystray und Pillow installiert"
} catch {
    Warn "pip-Installation fehlgeschlagen – Tray-Icon nicht verfügbar."
    Warn "Manuell: pip install pystray Pillow"
}

# ── 4. smb:// Protokoll-Handler in der Registry registrieren ─────────────────
Step "smb:// Protokoll in der Registry registrieren"

$regBase = "HKCU:\Software\Classes\smb"
$handlerCmd = "`"$pythonw`" `"$ScriptDest`" `"%1`""

# Basis-Schlüssel
New-Item    -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "(Default)"    -Value "URL:SMB Protocol"
Set-ItemProperty -Path $regBase -Name "URL Protocol" -Value ""

# Icon
$iconKey = "$regBase\DefaultIcon"
New-Item    -Path $iconKey -Force | Out-Null
Set-ItemProperty -Path $iconKey -Name "(Default)" `
    -Value "$env:SystemRoot\System32\imageres.dll,-25"

# Handler-Befehl
$cmdKey = "$regBase\shell\open\command"
New-Item    -Path $cmdKey -Force | Out-Null
Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value $handlerCmd

Ok "Registry: HKCU\Software\Classes\smb → $handlerCmd"

# ── 5. Autostart ──────────────────────────────────────────────────────────────
Step "Autostart einrichten"

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $AppName `
    -Value "`"$pythonw`" `"$ScriptDest`""

Ok "Autostart registriert"

# ── 6. Daemon starten ─────────────────────────────────────────────────────────
Step "Linky starten"

# Laufende Instanzen beenden (CimInstance funktioniert in PS5.1 + PS7)
Get-CimInstance Win32_Process -Filter "name='pythonw.exe'" |
    Where-Object { $_.CommandLine -like "*linky*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Milliseconds 300

Start-Process -FilePath $pythonw `
              -ArgumentList "`"$ScriptDest`"" `
              -WindowStyle Hidden

Start-Sleep -Seconds 1

$running = Get-CimInstance Win32_Process -Filter "name='pythonw.exe'" |
           Where-Object { $_.CommandLine -like "*linky*" }

if ($running) {
    Ok "Linky läuft im Hintergrund (PID $($running.ProcessId))"
} else {
    Warn "Linky konnte nicht automatisch gestartet werden."
    Warn "Manuell starten: pythonw `"$ScriptDest`""
}

# ── Fertig ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ✔ Installation abgeschlossen!" -ForegroundColor Green
Write-Host ""
Write-Host "  Skript:  $ScriptDest" -ForegroundColor DarkGray
Write-Host "  Handler: smb:// → Linky → Windows Explorer" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Nächste Schritte:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Klicke auf einen smb:// Link in Chrome, Edge oder Firefox."
Write-Host "     → Der Explorer öffnet den Netzwerkpfad direkt als \\server\freigabe"
Write-Host ""
Write-Host "  2. Falls der Browser fragt: 'Mit Linky öffnen' bestätigen."
Write-Host ""
Write-Host "  Deinstallieren:  powershell -File uninstall.ps1" -ForegroundColor DarkGray
Write-Host ""
