#Requires -Version 5.1
# Runs the whole install.ps1 and reads back the Windows Terminal settings it wrote.
# Expects a machine where tests\test-font-install.ps1 already put MesloLGM Nerd Font.
# ASCII only: this file has no BOM.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$InstallPath = Join-Path $Root 'install.ps1'
$script:Failures = 0

function Check($name, [bool]$ok) {
    if ($ok) { Write-Host "PASS  $name" }
    else { Write-Host "FAIL  $name"; $script:Failures++ }
}

# Same search order as install.ps1, so we read the file it writes.
$candidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$settings = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $settings) {
    $settings = $candidates[2]
    New-Item -ItemType Directory -Force -Path (Split-Path $settings -Parent) | Out-Null
}
Write-Host "settings file: $settings"

function Set-Settings($font) {
    $o = [ordered]@{ profiles = [ordered]@{ defaults = [ordered]@{ font = $font }; list = @() }; schemes = @() }
    [IO.File]::WriteAllText($settings, ($o | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
}
function Get-Font {
    ([IO.File]::ReadAllText($settings, [Text.Encoding]::UTF8) | ConvertFrom-Json).profiles.defaults.font
}
function Run-Installer([string[]]$extra) {
    $log = Join-Path $env:TEMP "install-$([guid]::NewGuid().ToString('N')).log"
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $InstallPath, '-Branch', 'main') + $extra
    $p = Start-Process powershell.exe -ArgumentList $argv -NoNewWindow -PassThru -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $text = (Get-Content $log -Raw -Encoding UTF8) + (Get-Content "$log.err" -Raw -Encoding UTF8)
    Write-Host '--- installer output (tail)'
    Write-Host (($text -split "`n" | Select-Object -Last 22) -join "`n")
    Write-Host "--- exit $($p.ExitCode)"
    return @{ Code = $p.ExitCode; Text = $text }
}

# Font present: the customer's rerun. Settings start with the stale name.
Set-Settings ([ordered]@{ face = 'MesloLGM Nerd Font'; size = 11 })
$r = Run-Installer @()
$f = Get-Font
Check 'font present: installer exits 0' ($r.Code -eq 0)
Check 'font present: face is set' ($f.face -eq 'MesloLGM Nerd Font')

# Font absent: a face that cannot be installed, with that name already stuck in settings.
Set-Settings ([ordered]@{ face = 'No Such Font'; size = 11 })
$r = Run-Installer @('-FontFace', 'No Such Font')
$f = Get-Font
Check 'font absent: installer still finishes' ($r.Code -eq 0)
Check 'font absent: stale face removed from settings' ($null -eq $f.face)
Check 'font absent: size kept' ($f.size -eq 11)

# Font absent, but the user picked another face: leave it alone.
Set-Settings ([ordered]@{ face = 'Consolas'; size = 11 })
$r = Run-Installer @('-FontFace', 'No Such Font')
$f = Get-Font
Check 'font absent: user face kept' ($f.face -eq 'Consolas')

if ($script:Failures) { throw "$script:Failures settings test(s) failed." }
Write-Output 'install-settings-tests: OK'
