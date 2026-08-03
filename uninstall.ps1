#Requires -Version 5.1
<#
.SYNOPSIS
    win-iterm2 가 만든 백업 중 가장 최근 것으로 되돌립니다.

.DESCRIPTION
    install.ps1 은 덮어쓰기 전에 항상 `<원본>.bak-<타임스탬프>` 를 남깁니다.
    이 스크립트는 그 백업을 되돌릴 뿐, winget 으로 설치한 패키지나
    폰트는 지우지 않습니다 (그건 `winget uninstall` 로 직접 하세요).
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$targets = @(
    (Join-Path $HOME '.config\oh-my-posh\snazzy.omp.json')
    (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

$restored = 0
foreach ($t in $targets) {
    $dir = Split-Path $t -Parent
    if (-not (Test-Path $dir)) { continue }

    $leaf = Split-Path $t -Leaf
    $bak = Get-ChildItem $dir -Filter "$leaf.bak-*" -ErrorAction Ignore |
        Sort-Object Name -Descending | Select-Object -First 1

    if (-not $bak) { Write-Host "  --   백업 없음: $leaf" -ForegroundColor DarkGray; continue }

    if ($PSCmdlet.ShouldProcess($t, "복원 <- $($bak.Name)")) {
        [System.IO.File]::WriteAllBytes($t, [System.IO.File]::ReadAllBytes($bak.FullName))
        Write-Host "  OK   $leaf  <-  $($bak.Name)" -ForegroundColor Green
        $restored++
    }
}

# 테마 캐시를 비우지 않으면 되돌린 설정이 반영되지 않습니다.
if (Get-Command oh-my-posh -ErrorAction Ignore) { oh-my-posh cache clear | Out-Null }

Write-Host "`n  $restored 개 복원됨. 터미널을 새로 여세요.`n" -ForegroundColor Green
