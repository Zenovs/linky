#Requires -Version 5.1
<#
.SYNOPSIS
    Linky – Windows Installer
.DESCRIPTION
    Installiert Linky als smb:// Protokoll-Handler mit Explorer-Kontextmenü.
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

# ── 1. Python prüfen / automatisch installieren ───────────────────────────────
Step "Python prüfen"

# Aktualisiert die PATH-Variable der aktuellen Session (nach einer Installation).
function Update-SessionPath {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

# Findet einen echten Python-3-Interpreter (überspringt den Microsoft-Store-Stub).
function Find-Python {
    foreach ($cmd in @("python", "python3", "py")) {
        $g = Get-Command $cmd -ErrorAction SilentlyContinue
        if (-not $g) { continue }
        $src = $g.Source
        if (-not $src) { continue }
        if ($src -like "*WindowsApps*") { continue }   # Store-Alias-Stub ignorieren
        try {
            $ver = & $cmd --version 2>&1
            if ($ver -match "Python 3") { return $cmd }
        } catch { }
    }
    return $null
}

$pyCmd = Find-Python

if (-not $pyCmd) {
    Warn "Python 3 nicht gefunden – wird automatisch installiert."

    # Versuch 1: winget (auf Windows 10 1809+ / 11 vorinstalliert)
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "  Installiere Python 3 via winget…" -ForegroundColor White
        try {
            & winget install -e --id Python.Python.3.12 --scope user `
                --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Update-SessionPath
            $pyCmd = Find-Python
        } catch {
            Warn "winget-Installation fehlgeschlagen: $_"
        }
    }

    # Versuch 2: Offiziellen Installer herunterladen und still installieren
    if (-not $pyCmd) {
        $pyVer = "3.12.7"
        $arch  = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
        $pyUrl = "https://www.python.org/ftp/python/$pyVer/python-$pyVer-$arch.exe"
        $pyExe = "$env:TEMP\linky-python-setup.exe"
        Write-Host "  Lade offiziellen Python-Installer ($pyVer $arch)…" -ForegroundColor White
        try {
            Invoke-WebRequest -Uri $pyUrl -OutFile $pyExe -UseBasicParsing
            Write-Host "  Installiere Python still (nur aktueller Benutzer, +PATH +pip)…" -ForegroundColor White
            Start-Process -FilePath $pyExe -Wait -ArgumentList @(
                "/quiet",
                "InstallAllUsers=0",
                "PrependPath=1",
                "Include_pip=1",
                "Include_launcher=1"
            )
            Remove-Item $pyExe -Force -ErrorAction SilentlyContinue
            Update-SessionPath
            $pyCmd = Find-Python
        } catch {
            Warn "Download/Installation fehlgeschlagen: $_"
        }
    }
}

if (-not $pyCmd) {
    Write-Host ""
    Write-Host "  Automatische Python-Installation nicht möglich." -ForegroundColor Yellow
    Write-Host "  Bitte manuell installieren: https://www.python.org/downloads/" -ForegroundColor White
    Write-Host "  (Haken setzen bei 'Add Python to PATH')" -ForegroundColor White
    Write-Host ""
    $open = Read-Host "  Jetzt python.org öffnen? [J/n]"
    if ($open -ne "n" -and $open -ne "N") {
        Start-Process "https://www.python.org/downloads/"
    }
    Fail "Python 3 wird benötigt."
}

# Echten Interpreter-Pfad auflösen (auch wenn via 'py'-Launcher gefunden).
$python = & $pyCmd -c "import sys; print(sys.executable)" 2>$null
if ($python) { $python = $python.Trim() }
if (-not $python -or -not (Test-Path $python)) {
    $python = (Get-Command $pyCmd -ErrorAction SilentlyContinue).Source
}

$pythonw = Join-Path (Split-Path $python) "pythonw.exe"
if (-not (Test-Path $pythonw)) { $pythonw = $python }

Ok "Python: $python"

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

# pip sicherstellen + aktualisieren (frische Python-Installs haben es schon,
# ältere oder abgespeckte evtl. nicht).
& $python -m ensurepip --upgrade 2>&1 | Out-Null
& $python -m pip install --quiet --upgrade pip 2>&1 | Out-Null

# Hinweis: try/catch fängt Exit-Codes externer EXEs NICHT — daher $LASTEXITCODE.
$pipOk = $false
& $python -m pip install --quiet pystray Pillow 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    $pipOk = $true
} else {
    # Fallback mit --user (falls system-weite Installation nicht erlaubt)
    & $python -m pip install --quiet --user pystray Pillow 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $pipOk = $true }
}

if ($pipOk) {
    Ok "pystray und Pillow installiert"
} else {
    Warn "pip-Installation fehlgeschlagen – Tray-Icon nicht verfügbar."
    Warn "Manuell: $python -m pip install pystray Pillow"
}

# ── 4. smb:// Protokoll-Handler registrieren ──────────────────────────────────
Step "smb:// Protokoll in der Registry registrieren"

$regBase    = "HKCU:\Software\Classes\smb"
$handlerCmd = "`"$pythonw`" `"$ScriptDest`" `"%1`""

New-Item -Path $regBase -Force | Out-Null
Set-ItemProperty -Path $regBase -Name "(Default)"    -Value "URL:SMB Protocol"
Set-ItemProperty -Path $regBase -Name "URL Protocol" -Value ""

$iconKey = "$regBase\DefaultIcon"
New-Item -Path $iconKey -Force | Out-Null
Set-ItemProperty -Path $iconKey -Name "(Default)" `
    -Value "$env:SystemRoot\System32\imageres.dll,-25"

$cmdKey = "$regBase\shell\open\command"
New-Item -Path $cmdKey -Force | Out-Null
Set-ItemProperty -Path $cmdKey -Name "(Default)" -Value $handlerCmd

Ok "smb:// → $handlerCmd"

# ── 5. Explorer-Kontextmenü ───────────────────────────────────────────────────
Step "Explorer-Kontextmenü registrieren"

# Befehlspfade
$copyCmd = "`"$pythonw`" `"$ScriptDest`" --copy `"%1`""
$openCmd = "`"$pythonw`" `"$ScriptDest`" --open `"%1`""

# Netzlaufwerk-Icon aus Shell32
$netIcon = "$env:SystemRoot\System32\shell32.dll,-275"

# Hilfsfunktion: Kontextmenü-Eintrag anlegen
function Register-ContextMenu {
    param($BasePath, $Name, $Label, $Cmd, $Icon)
    $shellPath = "$BasePath\shell\$Name"
    New-Item -Path "$shellPath\command" -Force | Out-Null
    Set-ItemProperty -Path $shellPath -Name "(Default)" -Value $Label
    Set-ItemProperty -Path $shellPath -Name "Icon"      -Value $Icon
    Set-ItemProperty -Path "$shellPath\command" -Name "(Default)" -Value $Cmd
}

# ── 5a. Rechtsklick auf Ordner (Directory) ────────────────────────────────────
$dirBase = "HKCU:\Software\Classes\Directory"
Register-ContextMenu -BasePath $dirBase -Name "LinkyKopieren" `
    -Label "SMB-Link kopieren" -Cmd $copyCmd -Icon $netIcon
Ok "Ordner: 'SMB-Link kopieren'"

# ── 5b. Rechtsklick in leerem Ordner-Bereich (Directory\Background) ───────────
# Hier gibt %V den aktuellen Ordnerpfad
$bgCopyCmd = "`"$pythonw`" `"$ScriptDest`" --copy `"%V`""
$bgBase = "HKCU:\Software\Classes\Directory\Background"
$bgPath = "$bgBase\shell\LinkyKopieren"
New-Item -Path "$bgPath\command" -Force | Out-Null
Set-ItemProperty -Path $bgPath -Name "(Default)" -Value "SMB-Link kopieren"
Set-ItemProperty -Path $bgPath -Name "Icon"      -Value $netIcon
Set-ItemProperty -Path "$bgPath\command" -Name "(Default)" -Value $bgCopyCmd
Ok "Hintergrund: 'SMB-Link kopieren'"

# ── 5c. Rechtsklick auf Laufwerk (Drive) ─────────────────────────────────────
$driveBase = "HKCU:\Software\Classes\Drive"
Register-ContextMenu -BasePath $driveBase -Name "LinkyKopieren" `
    -Label "SMB-Link kopieren" -Cmd $copyCmd -Icon $netIcon
Ok "Laufwerk: 'SMB-Link kopieren'"

# ── 5d. Rechtsklick auf Netzwerk-Ordner (Network) ────────────────────────────
$netBase = "HKCU:\Software\Classes\Network"
Register-ContextMenu -BasePath $netBase -Name "LinkyKopieren" `
    -Label "SMB-Link kopieren" -Cmd $copyCmd -Icon $netIcon
Ok "Netzwerk: 'SMB-Link kopieren'"

# ── 6. Autostart ──────────────────────────────────────────────────────────────
Step "Autostart einrichten"

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $AppName `
    -Value "`"$pythonw`" `"$ScriptDest`""
Ok "Autostart registriert"

# ── 7. Daemon starten ─────────────────────────────────────────────────────────
Step "Linky starten"

# Laufende Instanzen beenden (CimInstance = PS5.1 kompatibel)
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
    Ok "Linky läuft (PID $($running.ProcessId))"
} else {
    Warn "Linky konnte nicht automatisch gestartet werden."
    Warn "Manuell starten: pythonw `"$ScriptDest`""
}

# ── Fertig ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ✔ Installation abgeschlossen!" -ForegroundColor Green
Write-Host ""
Write-Host "  Skript:  $ScriptDest" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Features:" -ForegroundColor Yellow
Write-Host "  • smb:// Links in Browser/Mail/Teams anklicken → Explorer öffnet direkt"
Write-Host "  • SMB-Link in Zwischenablage → wird automatisch geöffnet"
Write-Host "  • Rechtsklick auf Netzwerkordner → 'SMB-Link kopieren'"
Write-Host "  • Tray-Icon mit Auto-Update und Autostart"
Write-Host ""
Write-Host "  Deinstallieren: powershell -File uninstall.ps1" -ForegroundColor DarkGray
Write-Host ""
