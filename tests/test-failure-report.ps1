#Requires -Version 5.1
# win-iterm2: progress bars stay off through the real entry point, and failures print one pasteable report.
# Runs after test-font-install.ps1 and test-install-settings.ps1 so the installer's tools are on this machine.
# ASCII only: this file has no BOM, so Korean text is built from code points.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
function Check($name, [bool]$ok) {
    if ($ok) { Write-Host "PASS  $name" } else { Write-Host "FAIL  $name"; $script:Failures++ }
}
function Korean([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }

$reportStart = Korean 0xC124,0xCE58,0x20,0xC2E4,0xD328,0x20,0xBCF4,0xACE0,0x20,0xC2DC,0xC791   # install failure report start
$partial     = Korean 0xC77C,0xBD80,0x20,0xBBF8,0xC644,0xB8CC                                  # partly unfinished
$stopped     = Korean 0xC911,0xB2E8,0xB428                                                     # stopped
$elapsed     = Korean 0xACBD,0xACFC,0x20                                                       # elapsed

$Root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "failure-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $work | Out-Null

function Run-Installer([string[]]$extra, [string]$path) {
    $log = Join-Path $work "out-$([guid]::NewGuid().ToString('N')).log"
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Root 'install.ps1'), '-Branch', 'main') + $extra
    $saved = $env:Path
    if ($path) { $env:Path = $path }
    $p = Start-Process powershell.exe -ArgumentList $argv -NoNewWindow -PassThru -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $env:Path = $saved
    $text = [IO.File]::ReadAllText($log, [Text.Encoding]::UTF8) + [IO.File]::ReadAllText("$log.err", [Text.Encoding]::UTF8)
    Write-Host "--- exit $($p.ExitCode)"
    Write-Host (($text -split "`n" | Select-Object -Last 16) -join "`n")
    return @{ Code = $p.ExitCode; Text = $text }
}

# --- get.ps1 through Invoke-Expression, the customer's way, with the download and child process stubbed.
$driver = Join-Path $work 'driver.ps1'
Set-Content -Path $driver -Encoding Ascii -Value @"
`$ProgressPreference = 'Inquire'
`$global:seen = 'not called'
function Invoke-WebRequest { param([switch]`$UseBasicParsing, [string]`$Uri, [string]`$OutFile) `$global:seen = `$ProgressPreference; Set-Content -Path `$OutFile -Value '' }
function powershell.exe { }
Invoke-Expression ([IO.File]::ReadAllText('$(Join-Path $Root 'get.ps1')'))
Write-Output "SEEN=`$global:seen"
Write-Output "AFTER=`$ProgressPreference"
"@
$out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $driver | Out-String)
Write-Host $out
Check 'get.ps1 downloads with progress bars off' ($out -match 'SEEN=SilentlyContinue')
Check 'get.ps1 leaves the caller window setting alone' ($out -match 'AFTER=Inquire')

# --- the same guard at the top of install.ps1, ahead of every statement that can download
$source = [IO.File]::ReadAllText((Join-Path $Root 'install.ps1'), [Text.Encoding]::UTF8)
Check 'install.ps1 turns progress bars off' ($source -match "(?m)^\`$ProgressPreference = 'SilentlyContinue'")
# Real Korean Windows, 2026-11-05: a progress bar over this separator raised IndexOutOfRangeException at widths 69, 71, 79.
# Hosted runners count the separator as one cell and cannot reproduce it, so this guards the two ingredients directly.
foreach ($file in 'get.ps1', 'install.ps1') {
    $code = [IO.File]::ReadAllText((Join-Path $Root $file), [Text.Encoding]::UTF8)
    Check "$file draws no progress bar and no wide separator" (($code -notmatch 'Write-Progress') -and (-not $code.Contains([string][char]0x2501)))
}
Check 'Install-Module child turns progress bars off' ($source -match "(?s)``\`$ProgressPreference = 'SilentlyContinue'\s+Set-PSRepository")

# --- the report itself, with a user folder inside the error text
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source.TrimStart([char]0xFEFF), [ref]$null, [ref]$null)
$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-FailureReport' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))
$script:StepLabel = '2/7 test'
$script:Stopwatch = [Diagnostics.Stopwatch]::StartNew()
$shown = (Write-FailureReport 'x' "cannot read $env:USERPROFILE\secret.txt`r`nsecond line") 6>&1 | Out-String
Check 'report hides the user folder' ((-not $shown.Contains($env:USERPROFILE)) -and $shown.Contains('~\secret.txt'))
Check 'report keeps a multi-line error on one line' ($shown -match 'secret\.txt second line')
$shown = (Write-FailureReport 'x' ("$([char]27)[31;1mFIRST_LINE$([char]27)[0m`nSECOND_LINE")) 6>&1 | Out-String
Check 'report strips ANSI and retains the error details' ((-not $shown.Contains([string][char]27)) -and $shown.Contains('FIRST_LINE SECOND_LINE'))


# --- font install fails: finishes with exit 0 and a partial report naming the font
$r = Run-Installer @('-FontFace', 'NoSuchFontX') $null
Check 'partial: exit code stays 0' ($r.Code -eq 0)
Check 'partial: report is printed' ($r.Text.Contains($reportStart))
Check 'partial: result says partly unfinished' ($r.Text.Contains($partial))
Check 'partial: report names the font and the step it failed on' ($r.Text -match '\[2/7 [^\]]*\][^\r\n]*NoSuchFontX')

# --- winget missing: stops with an error and a report
$noWinget = "$env:WINDIR\System32;$env:WINDIR;$env:WINDIR\System32\WindowsPowerShell\v1.0"
$r = Run-Installer @() $noWinget
Check 'stopped: exit code is not 0' ($r.Code -ne 0)
Check 'stopped: report is printed' ($r.Text.Contains($reportStart))
Check 'stopped: result says stopped' ($r.Text.Contains($stopped))
Check 'stopped: report names winget' ($r.Text -match 'winget')
Check 'stopped: report has the OS and PowerShell' ($r.Text -match 'OS: Windows \d' -and $r.Text -match 'PowerShell: 5\.1')

# --- a healthy rerun prints no report
$r = Run-Installer @() $null
Check 'healthy: exit code 0' ($r.Code -eq 0)
Check 'healthy: no report' (-not $r.Text.Contains($reportStart))

# --- the heartbeat: a fake winget that takes 20 seconds
$bin = Join-Path $work 'bin'
New-Item -ItemType Directory -Path $bin | Out-Null
Set-Content -Path (Join-Path $bin 'winget.cmd') -Encoding Ascii -Value "@ping -n 21 127.0.0.1 >nul`r`n@exit /b 0"
$r = Run-Installer @('-SkipFont', '-SkipTerminalSettings') "$bin;$env:Path"
Check 'heartbeat: elapsed line during a slow step' ($r.Text.Contains($elapsed))

if ($script:Failures) { throw "$script:Failures failure report test(s) failed." }
Write-Output 'failure-report-tests: OK'
