#Requires -Version 5.1
# Step [7] on a Korean Windows console (code page 949), the setup that garbled the labels for a customer.
# Runs the real Invoke-InstallVerify from install.ps1 in its own hidden console set to 949.
# Expects pwsh on PATH and the profile already placed (run after test-install-settings.ps1).
# ASCII only: this file has no BOM, so Korean text is built from code points.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Korean([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }
$expected = @(
    (Korean 0xD504, 0xB85C, 0xD544, 0x20, 0xB85C, 0xB4DC),   # profile load
    (Korean 0xD504, 0xB86C, 0xD504, 0xD2B8),                 # prompt
    (Korean 0xC544, 0xC774, 0xCF58),                         # icons
    'zoxide (z)',
    'fzf'
)

$Root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "cp949-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $work | Out-Null
$utf8 = New-Object Text.UTF8Encoding($true)

$childScript = Join-Path $work 'old-way.ps1'
[IO.File]::WriteAllText($childScript, "Write-Output '$($expected[0])'", $utf8)

$runner = Join-Path $work 'runner.ps1'
$runnerText = @"
`$ErrorActionPreference = 'Stop'
`$out = @()
try {
    [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(949)
    `$out += "CODEPAGE=`$([Console]::OutputEncoding.CodePage)"
    `$text = [IO.File]::ReadAllText('$(Join-Path $Root 'install.ps1')', [Text.Encoding]::UTF8)
    `$tokens = `$null; `$errors = `$null
    `$ast = [System.Management.Automation.Language.Parser]::ParseInput(`$text.TrimStart([char]0xFEFF), [ref]`$tokens, [ref]`$errors)
    foreach (`$name in 'Invoke-PwshFile', 'Format-VerifyLine', 'Invoke-InstallVerify') {
        `$fn = `$ast.Find({ param(`$n) `$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and `$n.Name -eq `$name }, `$true)
        . ([scriptblock]::Create(`$fn.Extent.Text))
    }
    `$Stamp = 'cp949test'
    `$captured = Invoke-InstallVerify 6>&1
    foreach (`$c in `$captured) { `$out += "NEW=`$c" }
    `$old = & pwsh -NoLogo -File '$($childScript)' 2>&1
    foreach (`$c in `$old) { `$out += "OLD=`$c" }
}
catch { `$out += "ERROR=`$(`$_.Exception.Message)" }
[IO.File]::WriteAllLines('$($work)\result.txt', [string[]]`$out, (New-Object Text.UTF8Encoding(`$false)))
"@
[IO.File]::WriteAllText($runner, $runnerText, $utf8)

# No -NoNewWindow: the child needs a console of its own to have a code page to set.
$p = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$runner`"" -WindowStyle Hidden -PassThru
if (-not $p.WaitForExit(180000)) { $p.Kill(); throw 'runner timed out' }

$result = [IO.File]::ReadAllLines((Join-Path $work 'result.txt'), [Text.Encoding]::UTF8)
$result | ForEach-Object { Write-Host "  $_" }

$failures = 0
if (-not ($result -contains 'CODEPAGE=949')) { Write-Host 'FAIL  console is not on code page 949'; $failures++ }
if ($result | Where-Object { $_ -like 'ERROR=*' }) { Write-Host 'FAIL  runner hit an error'; $failures++ }
foreach ($label in $expected) {
    $hit = $result | Where-Object { $_ -match ('^NEW=\s+' + [regex]::Escape($label) + '\s+(OK|FAIL)$') }
    if ($hit) { Write-Host "PASS  label intact on 949: $label" }
    else { Write-Host "FAIL  label missing or garbled on 949: $label"; $failures++ }
}

# Column alignment: the result starts at the same display column on every line.
$columns = foreach ($line in ($result | Where-Object { $_ -like 'NEW=*' })) {
    $body = $line.Substring(4)
    $m = [regex]::Match($body, '(OK|FAIL)$')
    if (-not $m.Success) { continue }
    $w = 0
    foreach ($c in $body.Substring(0, $m.Index).ToCharArray()) { $w += $(if ([int]$c -gt 127) { 2 } else { 1 }) }
    $w
}
$distinct = @($columns | Select-Object -Unique)
if ($distinct.Count -eq 1) { Write-Host "PASS  result column lines up ($($distinct[0]))" }
else { Write-Host "FAIL  result column differs: $($distinct -join ',')"; $failures++ }

# The old way, logged rather than asserted: shows what customers saw.
$old = $result | Where-Object { $_ -like 'OLD=*' }
Write-Host "old way (Korean through the pipe) printed: $old  intact=$($old -eq "OLD=$($expected[0])")"

if ($failures) { throw "$failures korean console test(s) failed." }
Write-Output 'korean-console-tests: OK'
