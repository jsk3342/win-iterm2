# One-time observation on a real Korean Windows PC. Installs nothing, changes no settings.
# Opens short-lived console windows, downloads small public files to TEMP, deletes them, prints a summary.
# ASCII only.
param([string]$ChildResult, [int]$ChildWidth, [string]$Case)
$OldSetup = 'https://raw.githubusercontent.com/jsk3342/claude-setup/9fc28467a308a5331fb9a3795952d6cc018f4bb0/install.ps1'
$NewSetup = 'https://raw.githubusercontent.com/jsk3342/claude-setup/main/install.ps1'
$Small = 'https://raw.githubusercontent.com/jsk3342/claude-setup/main/README.md'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Load-InstallerOutput($url) {
    $saved = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
    $source = (Invoke-WebRequest -UseBasicParsing $url).Content
    if ($source -is [byte[]]) { $source = [Text.Encoding]::UTF8.GetString($source) }
    $ProgressPreference = $saved
    return [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$null, [ref]$null)
}

if ($ChildResult) {
    $r = [ordered]@{ case = $Case; width = $ChildWidth; term = ''; ok = $false; error = ''; cp = 0; cells = ''; real = 0 }
    try {
        & "$env:SystemRoot\System32\mode.com" con: "cols=$ChildWidth" "lines=30" | Out-Null
        $r.cp = [Console]::OutputEncoding.CodePage
        $r.real = $Host.UI.RawUI.BufferSize.Width
        $r.term = $(if ($env:WT_SESSION) { 'WT' } else { 'conhost' })
        $r.cells = @(0x2501, 0xD55C | ForEach-Object { '{0:X4}={1}' -f $_, $Host.UI.RawUI.LengthInBufferCells([char]$_) }) -join ' '
        $korean = -join ([char[]](0xC124, 0xCE58, 0x20, 0xC911))
        if ($Case -in 'oldSetup', 'newSetup') {
            $ast = Load-InstallerOutput $(if ($Case -eq 'oldSetup') { $OldSetup } else { $NewSetup })
            foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in 'Write-Step', 'Write-Ok', 'Write-Skip', 'Start-StepHeartbeat', 'Stop-StepHeartbeat' }, $false)) {
                . ([scriptblock]::Create($fn.Extent.Text))
            }
            foreach ($s in $ast.EndBlock.Statements) {
                if ($s.Extent.Text -match '^\$(ErrorActionPreference|savedProgressPreference|ProgressPreference)\s*=') { . ([scriptblock]::Create($s.Extent.Text)) }
            }
            foreach ($round in 1..2) { foreach ($step in 1..7) {
                Write-Step -Num $step -Total 7 -Message 'Python 3' -Reason ($korean * 8)
                Write-Skip "Python 3.15.2 round $round"
                Write-Ok 'done'
            } }
            if (Get-Command Stop-StepHeartbeat -ErrorAction Ignore) { Stop-StepHeartbeat }
        }
        else {
            $ErrorActionPreference = 'Stop'
            $ProgressPreference = $(if ($Case -eq 'barOn') { 'Continue' } else { 'SilentlyContinue' })
            $file = Join-Path $env:TEMP "korean-observe-$PID.bin"
            foreach ($i in 1..4) {
                Write-Host ($korean * 14)
                Invoke-WebRequest -UseBasicParsing $Small -OutFile $file
                Write-Host ($korean * 14)
            }
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
        $r.ok = $true
    }
    catch { $r.error = "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
    $r | ConvertTo-Json -Compress | Set-Content -LiteralPath $ChildResult -Encoding UTF8
    exit 0
}

$started = Get-Date
$lines = New-Object System.Collections.ArrayList
foreach ($launcher in 'default', 'conhost') {
    foreach ($case in 'oldSetup', 'newSetup', 'barOn', 'barOff') {
        foreach ($width in 69, 71, 79, 120) {
            $path = Join-Path $env:TEMP "korean-observe-$launcher-$case-$width.json"
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            $args1 = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ChildResult `"$path`" -ChildWidth $width -Case $case"
            if ($launcher -eq 'conhost') { $p = Start-Process conhost.exe -ArgumentList "powershell.exe $args1" -PassThru }
            else { $p = Start-Process powershell.exe -ArgumentList $args1 -PassThru }
            $null = $p.WaitForExit(60000)
            if (Test-Path $path) {
                $o = Get-Content $path -Raw | ConvertFrom-Json
                $msg = "{0,-7} {1,-8} w{2,-3} real={3,-3} {4,-7} cp={5} [{6}] ok={7} {8}" -f $launcher, $case, $width, $o.real, $o.term, $o.cp, $o.cells, $o.ok, $o.error
                Remove-Item $path -Force -ErrorAction SilentlyContinue
            } else { $msg = "{0,-7} {1,-8} w{2,-3} NO_RESULT" -f $launcher, $case, $width }
            [void]$lines.Add($msg); Write-Host $msg
        }
    }
}

# Does an elapsed line stay on its own row when another program left a line unfinished?
$ast = Load-InstallerOutput $NewSetup
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in 'Start-StepHeartbeat', 'Stop-StepHeartbeat' }, $false)) { . ([scriptblock]::Create($fn.Extent.Text)) }
$script:stepHeartbeat = $null
Write-Host ''
Write-Host 'GLUE-CHECK: unfinished line follows' -ForegroundColor Cyan
Write-Host 'Extracting node-v26.7z...' -NoNewline
Start-StepHeartbeat
Start-Sleep -Seconds 17
Stop-StepHeartbeat
Write-Host ''

Write-Host ''
Write-Host "=== SUMMARY $([int]((Get-Date) - $started).TotalSeconds)s  failed:" -ForegroundColor Cyan
$lines | Where-Object { $_ -notmatch 'ok=True' } | ForEach-Object { Write-Host $_ }
Write-Host "=== passed: $(@($lines | Where-Object { $_ -match 'ok=True' }).Count) of $($lines.Count)" -ForegroundColor Cyan
Write-Host 'OBSERVE-DONE' -ForegroundColor Green
