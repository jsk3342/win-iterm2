#Requires -Version 5.1
# Font step of install.ps1 on real Windows PowerShell 5.1.
# Runs the actual functions out of install.ps1 (via the parser) against fake and real oh-my-posh.
# ASCII only: this file has no BOM.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$InstallPath = Join-Path $Root 'install.ps1'
$Face = 'MesloLGM Nerd Font'
$script:Failures = 0

function Check($name, [bool]$ok) {
    if ($ok) { Write-Host "PASS  $name" }
    else { Write-Host "FAIL  $name"; $script:Failures++ }
}

# Output helpers install.ps1 defines at top level.
function Ok($m) { Write-Host "    [ok] $m" }
function Skip($m) { Write-Host "    [skip] $m" }
function Warn($m) { Write-Host "    [warn] $m" }

$text = [IO.File]::ReadAllText($InstallPath, [Text.Encoding]::UTF8)
Check 'install.ps1 does not pass the removed --headless flag' ($text -notmatch '--headless')

$errors = $null; $tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($text.TrimStart([char]0xFEFF), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'install.ps1 does not parse.' }
foreach ($name in 'Test-FontInstalled', 'Install-NerdFont', 'Resolve-FontFace') {
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    if (-not $fn) { throw "install.ps1 has no function $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}

# --- Resolve-FontFace
Check 'face used when font is ready'             ((Resolve-FontFace $Face $true 'Consolas') -eq $Face)
Check 'missing font clears our own stale face'   ($null -eq (Resolve-FontFace $Face $false $Face))
Check 'missing font keeps the user''s other face' ((Resolve-FontFace $Face $false 'Consolas') -eq 'Consolas')
Check 'missing font with no face stays empty'    ($null -eq (Resolve-FontFace $Face $false $null))

# --- settings merge: the shape the installer writes when the font is missing
$tmpl = [IO.File]::ReadAllText((Join-Path $Root 'config\terminal-settings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$font = $tmpl.profiles.defaults.font
$font.PSObject.Properties.Remove('face')
$json = $tmpl | ConvertTo-Json -Depth 32
Check 'template font object can drop face and keep size' (($null -eq $font.face) -and ($font.size -eq 11) -and ($json -notmatch [regex]::Escape('"face":  "MesloLGM')))

# --- font must be absent for the install cases to mean anything
if (Test-FontInstalled $Face) { throw "$Face is already on this machine; the cases below would prove nothing." }

$bin = Join-Path $env:TEMP "font-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $bin | Out-Null
$originalPath = $env:Path
$env:Path = "$bin;$originalPath"

# --- fake oh-my-posh: rejects the call, nothing installed
Set-Content -Path (Join-Path $bin 'oh-my-posh.cmd') -Value "@echo Error: unknown flag`r`n@exit /b 70" -Encoding Ascii
$r = Install-NerdFont $Face
Check 'exit 70 -> not ready' ($r -is [bool] -and $r -eq $false)

# --- fake oh-my-posh: claims success, nothing installed
Set-Content -Path (Join-Path $bin 'oh-my-posh.cmd') -Value '@exit /b 0' -Encoding Ascii
$r = Install-NerdFont $Face
Check 'exit 0 without a font -> not ready' ($r -is [bool] -and $r -eq $false)
Remove-Item (Join-Path $bin 'oh-my-posh.cmd')

# --- oh-my-posh missing altogether
$env:Path = "$bin;$env:WINDIR\System32"
$r = Install-NerdFont $Face
Check 'oh-my-posh not found -> not ready, no throw' ($r -is [bool] -and $r -eq $false)
$env:Path = "$bin;$originalPath"

# --- real oh-my-posh, same release winget serves
$exe = Join-Path $bin 'oh-my-posh.exe'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe' -OutFile $exe
Write-Host "oh-my-posh version: $(& $exe version)"

# What customers got before the fix. Logged, not asserted: upstream can change this any time.
$ErrorActionPreference = 'Continue'
$out = & $exe font install meslo --headless 2>&1 | Out-String
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Write-Host "old call (--headless) exit=$code font_present=$(Test-FontInstalled $Face)"
Write-Host ($out -split "`n" | Select-Object -First 2 | Out-String)

$r = Install-NerdFont $Face
Check 'real install -> ready' ($r -is [bool] -and $r -eq $true)
Check 'font visible after install' (Test-FontInstalled $Face)

$entries = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction Ignore
if ($entries) {
    Write-Host 'HKCU MesloLGM entries:'
    $entries.PSObject.Properties | Where-Object Name -like 'MesloLGM Nerd Font*' | ForEach-Object { Write-Host "  $($_.Name) = $($_.Value)" }
}

# Fresh process: what the next run and a newly opened terminal's system would see.
$probe = Join-Path $bin 'probe.ps1'
Set-Content -Path $probe -Encoding Ascii -Value "Add-Type -AssemblyName System.Drawing; ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains '$Face')"
$fresh = (& powershell.exe -NoProfile -File $probe | Out-String).Trim()
Write-Host "GDI+ in a fresh process sees the font: $fresh"
Check 'fresh process sees the font via GDI+' ($fresh -eq 'True')

$r = Install-NerdFont $Face
Check 'second run -> ready without reinstalling' ($r -is [bool] -and $r -eq $true)

$env:Path = $originalPath
if ($script:Failures) { throw "$script:Failures font test(s) failed." }
Write-Output 'font-install-tests: OK'
