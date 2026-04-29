#Requires -Version 5.1
<#
.SYNOPSIS
    Linky – Windows Deinstaller
.DESCRIPTION
    Entfernt Linky vollständig (Registry, Autostart, Dateien).
    Ausführen mit:
        powershell -ExecutionPolicy Bypass -File uninstall.ps1
#>

$ErrorActionPreference = "SilentlyContinue"

$AppName    = "Linky"
$InstallDir = "$env:LOCALAPPDATA\Linky"

function Ok($msg) { Write-Host "  ✔  $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "  Linky – Deinstallation" -ForegroundColor Cyan
Write-Host ""

# Prozess beenden (CimInstance funktioniert in PS5.1 + PS7)
Get-CimInstance Win32_Process -Filter "name='pythonw.exe'" |
    Where-Object { $_.CommandLine -like "*linky*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Ok "Prozess beendet"

# Registry: Protokoll-Handler
Remove-Item "HKCU:\Software\Classes\smb" -Recurse -Force -ErrorAction SilentlyContinue
Ok "smb:// Protokoll entfernt"

# Registry: Autostart
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Remove-ItemProperty -Path $runKey -Name $AppName -Force -ErrorAction SilentlyContinue
Ok "Autostart entfernt"

# Installationsverzeichnis
Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
Ok "Installationsverzeichnis entfernt: $InstallDir"

Write-Host ""
Write-Host "  ✔ Linky wurde vollständig entfernt." -ForegroundColor Green
Write-Host ""
