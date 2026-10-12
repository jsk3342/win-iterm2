#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$InstallPath = Join-Path $Root 'install.ps1'
$ReadmePath = Join-Path $Root 'README.md'

$bytes = [System.IO.File]::ReadAllBytes($InstallPath)
$preamble = [System.Text.Encoding]::UTF8.GetPreamble()
if ($bytes.Length -lt $preamble.Length) {
    throw 'install.ps1 is unexpectedly empty.'
}
for ($i = 0; $i -lt $preamble.Length; $i++) {
    if ($bytes[$i] -ne $preamble[$i]) {
        throw 'install.ps1 must keep its UTF-8 BOM for Windows PowerShell 5.1 file execution.'
    }
}

$remoteText = [System.Text.Encoding]::UTF8.GetString($bytes)
if ($remoteText[0] -ne [char]0xFEFF) {
    throw 'The remote-text regression fixture did not preserve the BOM character.'
}

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput(
    $remoteText.TrimStart([char]0xFEFF),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
if ($errors.Count) {
    $messages = ($errors | ForEach-Object Message) -join [Environment]::NewLine
    throw "install.ps1 fails after BOM-safe loading:`n$messages"
}

$readme = [System.IO.File]::ReadAllText($ReadmePath, [System.Text.Encoding]::UTF8)
if ($readme -match 'install\.ps1\s*\|\s*iex') {
    throw 'README must not pipe the BOM-bearing install.ps1 directly to Invoke-Expression.'
}
if ($readme -notmatch 'get\.ps1\s*\|\s*iex') {
    throw 'README is missing the get.ps1 one-line entrypoint.'
}

# get.ps1 is piped to iex, so it must be pure ASCII without a BOM.
$GetPath = Join-Path $Root 'get.ps1'
$getBytes = [System.IO.File]::ReadAllBytes($GetPath)
if ($getBytes | Where-Object { $_ -gt 127 }) {
    throw 'get.ps1 must be ASCII-only (no BOM, no Korean) to survive irm | iex.'
}
$getText = [System.Text.Encoding]::ASCII.GetString($getBytes)
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput($getText, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) {
    throw "get.ps1 does not parse:`n$(($errors | ForEach-Object Message) -join [Environment]::NewLine)"
}
if ($getText -notmatch 'Invoke-WebRequest[^\r\n]+install\.ps1[^\r\n]+-OutFile' -or $getText -notmatch 'powershell\.exe[^\r\n]+-File') {
    throw 'get.ps1 must download install.ps1 to a file and run it with -File.'
}

Write-Output 'installer-entrypoint-tests: OK'
