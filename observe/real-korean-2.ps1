# One-time observation on a real Korean Windows PC. Installs nothing, changes no settings.
# Question: can the error still appear on a rerun in the same window, before or after our script starts?
# ASCII only.
param([string]$ChildResult, [int]$ChildWidth, [string]$Case)
$Installer = 'https://raw.githubusercontent.com/jsk3342/claude-setup/main/install.ps1'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($ChildResult) {
    $r = [ordered]@{ case = $Case; width = $ChildWidth; ok = $false; error = ''; at = ''; cp = 0 }
    try {
        & "$env:SystemRoot\System32\mode.com" con: "cols=$ChildWidth" "lines=30" | Out-Null
        $r.cp = [Console]::OutputEncoding.CodePage
        $korean = -join ([char[]](0xC124, 0xCE58, 0x20, 0xC911))
        $screen, $action = $Case -split '\+'
        $saved = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $text = (Invoke-WebRequest -UseBasicParsing $Installer).Content
        if ($text -is [byte[]]) { $text = [Text.Encoding]::UTF8.GetString($text) }
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
        $r.at = 'screen'
        if ($screen -eq 'old') {
            $bar = [string][char]0x2501 * 40
            foreach ($i in 1..7) { Write-Host $bar; Write-Host ($korean * 8); Write-Host $bar }
        }
        elseif ($screen -eq 'new') {
            foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in 'Write-Step', 'Write-Ok', 'Write-Skip', 'Start-StepHeartbeat', 'Stop-StepHeartbeat' }, $false)) {
                . ([scriptblock]::Create($fn.Extent.Text))
            }
            $script:stepHeartbeat = $null
            foreach ($step in 1..7) {
                Write-Step -Num $step -Total 7 -Message 'Python 3' -Reason ($korean * 8)
                Write-Skip "Python 3.15.2"
                Write-Ok 'done'
            }
            Stop-StepHeartbeat
        }
        else { foreach ($i in 1..7) { Write-Host ($korean * 8) } }
        $ProgressPreference = $saved
        $ErrorActionPreference = 'Stop'
        $r.at = $action
        if ($action -eq 'irm') {
            # The pasted command's own download, with the window's default progress setting.
            foreach ($i in 1..4) { $null = Invoke-RestMethod -Uri $Installer; Write-Host ($korean * 8) }
        }
        else {
            # A progress bar for certain, then output under it.
            foreach ($i in 1..4) {
                Write-Progress -Id 71 -Activity ($korean * 3) -Status 'step' -PercentComplete (20 * $i)
                Write-Host ($korean * 8)
            }
            Write-Progress -Id 71 -Activity ($korean * 3) -Completed
        }
        $r.ok = $true
    }
    catch { $r.error = "$($_.Exception.GetType().Name)" }
    $r | ConvertTo-Json -Compress | Set-Content -LiteralPath $ChildResult -Encoding UTF8
    exit 0
}

$lines = New-Object System.Collections.ArrayList
foreach ($case in 'old+bar', 'old+irm', 'new+bar', 'new+irm', 'plain+irm') {
    foreach ($width in 69, 71, 79, 120) {
        $path = Join-Path $env:TEMP "korean-observe2-$($case -replace '\+','-')-$width.json"
        Remove-Item $path -Force -ErrorAction SilentlyContinue
        $p = Start-Process conhost.exe -ArgumentList "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ChildResult `"$path`" -ChildWidth $width -Case $case" -PassThru
        $null = $p.WaitForExit(60000)
        if (Test-Path $path) {
            $o = Get-Content $path -Raw | ConvertFrom-Json
            $msg = "{0,-10} w{1,-3} cp={2} ok={3} {4} {5}" -f $case, $width, $o.cp, $o.ok, $o.at, $o.error
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        } else { $msg = "{0,-10} w{1,-3} NO_RESULT" -f $case, $width }
        [void]$lines.Add($msg); Write-Host $msg
    }
}
Write-Host "=== passed: $(@($lines | Where-Object { $_ -match 'ok=True' }).Count) of $($lines.Count)" -ForegroundColor Cyan
Write-Host 'OBSERVE-DONE' -ForegroundColor Green
