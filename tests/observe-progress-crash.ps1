# Observation only, not kept on main: real console, code page 949, narrow widths, download with progress bars on.
param([string]$ChildResult, [int]$ChildWidth, [string]$Pref)
$url = 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe'
if ($ChildResult) {
    $r = [ordered]@{ width = $ChildWidth; pref = $Pref; ok = $false; error = ''; cp = 0; cells = '' }
    try {
        $ErrorActionPreference = 'Stop'
        [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(949)
        & "$env:SystemRoot\System32\mode.com" con: "cols=$ChildWidth" "lines=30" | Out-Null
        $r.cp = [Console]::OutputEncoding.CodePage
        $r.cells = @(0x2501, 0xD55C | ForEach-Object { '{0:X4}={1}' -f $_, $Host.UI.RawUI.LengthInBufferCells([char]$_) }) -join ' '
        $ProgressPreference = $Pref
        $korean = -join ([char[]](0xC124,0xCE58,0x20,0xC911))
        foreach ($i in 1..3) {
            Write-Host ($korean * 12)
            Invoke-WebRequest -UseBasicParsing $url -OutFile (Join-Path $env:TEMP "observe-$PID.bin")
            Write-Host ($korean * 12)
        }
        $r.ok = $true
    }
    catch { $r.error = "$($_.Exception.GetType().FullName): $($_.Exception.Message)" }
    $r | ConvertTo-Json -Compress | Set-Content -LiteralPath $ChildResult -Encoding UTF8
    exit 0
}
foreach ($pref in 'Continue', 'SilentlyContinue') {
    foreach ($width in 60, 66, 69, 71, 80) {
        $path = Join-Path $env:TEMP "observe-$width-$pref.json"
        $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-ChildResult', "`"$path`"", '-ChildWidth', $width, '-Pref', $pref)
        $p = Start-Process powershell.exe -ArgumentList $argv -PassThru -WindowStyle Normal
        if (-not $p.WaitForExit(180000)) { $p.Kill(); Write-Host "width=$width pref=$pref TIMEOUT"; continue }
        Write-Host (Get-Content -LiteralPath $path -Raw)
    }
}
