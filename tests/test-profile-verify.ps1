#Requires -Version 5.1
# Exercise the real capture process and verifier without changing this PC's profile.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$source = [IO.File]::ReadAllText((Join-Path $Root 'install.ps1'), [Text.Encoding]::UTF8)
$ast = [Management.Automation.Language.Parser]::ParseInput($source.TrimStart([char]0xFEFF), [ref]$null, [ref]$null)
foreach ($name in 'Invoke-PwshFile', 'Resolve-PwshProfile', 'Format-VerifyLine', 'Invoke-InstallVerify') {
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    if (-not $fn) { throw "Missing function: $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
$realCapture = ${function:Invoke-PwshFile}
$script:Failures = 0
function Check($name, [bool]$ok) {
    if ($ok) { Write-Host "PASS  $name" } else { Write-Host "FAIL  $name"; $script:Failures++ }
}
$utf8 = New-Object Text.UTF8Encoding($true)
$work = Join-Path $env:TEMP ("profile verify " + [char]0xD55C + [char]0xAE00 + ' ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$fixture = Join-Path $work 'redirected documents\PowerShell\Microsoft.PowerShell_profile.ps1'
New-Item -ItemType Directory -Path (Split-Path $fixture -Parent) | Out-Null
$Stamp = [guid]::NewGuid().ToString('N')
$script:StepLabel = '7/7 verify'
try {
    $actual = Resolve-PwshProfile
    $expected = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
    Check 'profile follows the Windows Documents known folder' ($actual -eq $expected)
    Check 'installer uses the resolved path rather than HOME Documents' ($source -match '(?m)^\$pwshProfile = Resolve-PwshProfile\s*$')

    # Substitute only the profile under test, preserving the real child-process path.
    function Invoke-PwshFile([string]$Path) {
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        $text = $text.Replace('. $PROFILE', (". '" + $fixture.Replace("'", "''") + "'"))
        [IO.File]::WriteAllText($Path, $text, $utf8)
        & $realCapture $Path
    }
    $healthy = @'
$env:WIN_ITERM_TEST_LOADS = [int]$env:WIN_ITERM_TEST_LOADS + 1
if ($env:WIN_ITERM_TEST_LOADS -ne '1') { throw 'PROFILE_LOADED_TWICE' }
function global:z { }
function global:fzf { }
New-Module -Name Terminal-Icons -ScriptBlock {} | Import-Module
'@
    [IO.File]::WriteAllText($fixture, $healthy, $utf8)
    $script:Problems = @()
    $out = Invoke-InstallVerify 6>&1 | Out-String
    Check 'redirected profile in a Unicode path loads once and passes all checks' ($script:Problems.Count -eq 0 -and ([regex]::Matches($out, '\bOK\b')).Count -eq 5)

    # Real stderr with multiple lines must survive PS 5.1 Stop and CP949.
    $savedEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(949)
        $detail = 'SECOND_LINE_' + [char]0xD55C + [char]0xAE00
        [IO.File]::WriteAllText($fixture, ('throw "FIRST_LINE`n' + $detail + '"'), $utf8)
        $failure = ''
        try { Invoke-InstallVerify } catch { $failure = $_.Exception.Message }
        Check 'full error includes later lines and Unicode under CP949' ($failure.Contains('FIRST_LINE') -and $failure.Contains($detail))
        Check 'failed verification removes its temporary script' (-not (Test-Path (Join-Path $env:TEMP "win-iterm2-verify-$Stamp.ps1")))
    }
    finally { [Console]::OutputEncoding = $savedEncoding }

    Remove-Item $fixture -Force
    $failure = ''
    try { Invoke-InstallVerify } catch { $failure = $_.Exception.Message }
    Check 'missing redirected profile is an actionable failure' ($failure -match 'profile verification failed' -and $failure.Contains('Microsoft.PowerShell_profile.ps1'))

    # An empty or truncated response must never be reported as successful verification.
    function Invoke-PwshFile([string]$Path) { return @{ ExitCode = 0; Output = ''; Error = '' } }
    $failure = ''
    try { Invoke-InstallVerify } catch { $failure = $_.Exception.Message }
    Check 'missing check results fail verification' ($failure -match 'all five checks')

    function Invoke-PwshFile([string]$Path) { return @{ ExitCode = 9; Output = ''; Error = '' } }
    $failure = ''
    try { Invoke-InstallVerify } catch { $failure = $_.Exception.Message }
    Check 'nonzero exit fails even without stderr' ($failure -match 'exit 9')
}
finally { Remove-Item $work -Recurse -Force -ErrorAction Ignore }
if ($script:Failures) { throw "$script:Failures profile verification test(s) failed." }
Write-Output 'profile-verify-tests: OK'
