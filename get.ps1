# win-iterm2 one-line entrypoint:
#   irm https://raw.githubusercontent.com/jsk3342/win-iterm2/main/get.ps1 | iex
#
# Keep this file ASCII-only without a BOM so Windows PowerShell 5.1 can pipe it to iex.
# install.ps1 keeps its BOM (Korean text), so it is saved to a file and run with -File.
& {
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $p = Join-Path $env:TEMP 'win-iterm2-install.ps1'
    Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/jsk3342/win-iterm2/main/install.ps1' -OutFile $p
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p
}
