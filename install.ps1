#Requires -Version 5.1
<#
.SYNOPSIS
    win-iterm2 — Windows 터미널을 맥 iTerm2 감성으로 한 번에 구성합니다.

.DESCRIPTION
    Windows Terminal + PowerShell 7 + oh-my-posh + Nerd Font + zoxide + fzf 를
    설치하고, 터미널 배색/폰트/투명도까지 자동으로 설정합니다.
    관리자 권한이 필요 없습니다 (전부 사용자 범위 설치).

    이미 설치된 항목은 건너뛰므로 여러 번 실행해도 안전합니다.

.PARAMETER Scheme
    기본 배색. Snazzy(기본) / Tokyo Night Storm / Dracula / Nord

.EXAMPLE
    irm https://raw.githubusercontent.com/USER/win-iterm2/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -Scheme 'Tokyo Night Storm' -Opacity 100
#>
[CmdletBinding()]
param(
    [ValidateSet('Snazzy', 'Tokyo Night Storm', 'Dracula', 'Nord')]
    [string]$Scheme = 'Snazzy',

    [ValidateRange(30, 100)]
    [int]$Opacity = 88,

    [ValidateRange(6, 32)]
    [int]$FontSize = 11,

    [string]$FontFace = 'MesloLGM Nerd Font',

    [switch]$SkipFont,
    [switch]$SkipTerminalSettings,

    [string]$Repo = 'USER/win-iterm2',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# ─────────────────────────── 출력 헬퍼 ───────────────────────────
$script:StepNo = 0
function Step($msg) { $script:StepNo++; Write-Host "`n[$script:StepNo] $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "    OK   $msg" -ForegroundColor Green }
function Skip($msg) { Write-Host "    --   $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "    !    $msg" -ForegroundColor Yellow }

# ───────────────────────── 공통 유틸리티 ─────────────────────────

# winget 설치 직후에는 새 실행 파일이 현재 세션 PATH에 없습니다.
# 레지스트리에서 PATH를 다시 읽어와야 같은 세션에서 바로 호출할 수 있습니다.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user | Where-Object { $_ }) -join ';'
}

function Test-CommandExists($name) {
    [bool](Get-Command $name -ErrorAction Ignore)
}

function Install-WingetPackage($id, $label) {
    $listed = winget list --id $id -e --accept-source-agreements 2>$null | Out-String
    if ($listed -match [regex]::Escape($id)) { Skip "$label 이미 설치됨"; return }

    Write-Host "         $label 설치 중..." -ForegroundColor DarkGray
    winget install --id $id -e --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -ne 0) { Warn "$label 설치가 실패했을 수 있습니다 (exit $LASTEXITCODE)" }
    else { Ok "$label 설치됨" }
    Update-SessionPath
}

function Install-PSModule($name) {
    $found = pwsh -NoProfile -Command "[bool](Get-Module -ListAvailable -Name $name)" 2>$null
    if ($found -eq 'True') { Skip "$name 이미 설치됨"; return }
    pwsh -NoProfile -Command @"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
Install-Module $name -Scope CurrentUser -Force -AllowClobber -AcceptLicense
"@ | Out-Null
    Ok "$name 설치됨"
}

# 리포를 클론했으면 로컬 파일을, `irm | iex` 로 실행했으면 GitHub raw 를 씁니다.
# 어느 쪽이든 바이트 단위로 그대로 옮깁니다 — 텍스트로 읽으면 Nerd Font 글리프가 깨집니다.
$script:LocalRoot = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'config'))) {
    $script:LocalRoot = $PSScriptRoot
}

function Copy-Asset($relPath, $destPath) {
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

    if ($script:LocalRoot) {
        $src = Join-Path $script:LocalRoot $relPath
        [System.IO.File]::WriteAllBytes($destPath, [System.IO.File]::ReadAllBytes($src))
    }
    else {
        $url = "https://raw.githubusercontent.com/$Repo/$Branch/$($relPath -replace '\\','/')"
        Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing
    }
}

function Backup-File($path) {
    if (Test-Path $path) {
        $bak = "$path.bak-$Stamp"
        Copy-Item $path $bak -Force
        Ok "백업: $(Split-Path $bak -Leaf)"
    }
}

# PSCustomObject 에 속성을 안전하게 설정 (있으면 덮어쓰고, 없으면 추가)
function Set-Prop($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
}

# ═══════════════════════════ 실행 ═══════════════════════════

Write-Host @"

  win-iterm2  —  맥 iTerm2 감성의 Windows 터미널
  배색: $Scheme  |  폰트: $FontFace ${FontSize}pt  |  투명도: $Opacity%

"@ -ForegroundColor Magenta

if (-not (Test-CommandExists winget)) {
    throw "winget 을 찾을 수 없습니다. Microsoft Store 에서 '앱 설치 관리자'를 업데이트한 뒤 다시 실행하세요."
}

# ── 1. 패키지 설치 ───────────────────────────────────────────
Step '패키지 설치 (Windows Terminal / PowerShell 7 / oh-my-posh / zoxide / fzf)'
Install-WingetPackage 'Microsoft.WindowsTerminal' 'Windows Terminal'
Install-WingetPackage 'Microsoft.PowerShell'      'PowerShell 7'
Install-WingetPackage 'JanDeDobbeleer.OhMyPosh'   'oh-my-posh'
Install-WingetPackage 'ajeetdsouza.zoxide'        'zoxide'
Install-WingetPackage 'junegunn.fzf'              'fzf'
Update-SessionPath

if (-not (Test-CommandExists pwsh)) {
    throw "PowerShell 7(pwsh) 설치를 확인할 수 없습니다. 터미널을 새로 열고 다시 실행하세요."
}

# ── 2. Nerd Font ─────────────────────────────────────────────
Step 'Nerd Font 설치'
if ($SkipFont) {
    Skip '-SkipFont 지정됨'
}
else {
    Add-Type -AssemblyName System.Drawing
    $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($installed -contains $FontFace) {
        Skip "$FontFace 이미 설치됨"
    }
    else {
        # --headless 로 TUI 없이 사용자 범위(%LOCALAPPDATA%)에 설치 — 관리자 권한 불필요
        oh-my-posh font install meslo --headless
        Ok "$FontFace 설치됨"
    }
}

# ── 3. PowerShell 모듈 ───────────────────────────────────────
Step 'PowerShell 모듈 설치 (Terminal-Icons / PSFzf)'
Install-PSModule 'Terminal-Icons'
Install-PSModule 'PSFzf'

# ── 4. oh-my-posh 테마 ───────────────────────────────────────
Step 'oh-my-posh 테마 배치'
$themePath = Join-Path $HOME '.config\oh-my-posh\snazzy.omp.json'
Backup-File $themePath
Copy-Asset 'config/snazzy.omp.json' $themePath
Ok $themePath

# oh-my-posh v26+ 는 설정을 캐시합니다. 비우지 않으면 새 테마가 무시되고
# 프롬프트에 'CONFIG NOT FOUND' 가 그대로 뜹니다.
oh-my-posh cache clear | Out-Null
Ok '설정 캐시 비움'

# ── 5. PowerShell 프로필 ─────────────────────────────────────
Step 'PowerShell 프로필 배치'
$pwshProfile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
Backup-File $pwshProfile
Copy-Asset 'config/profile.ps1' $pwshProfile
Ok $pwshProfile

# ── 6. Windows Terminal 설정 ─────────────────────────────────
Step 'Windows Terminal 설정 (폰트 / 배색 / 투명도 / 단축키)'

if ($SkipTerminalSettings) {
    Skip '-SkipTerminalSettings 지정됨'
}
else {
    # Store 판, Preview 판, 비패키지 판 순으로 탐색
    $wtCandidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtPath = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    # 설정 파일은 Windows Terminal 을 한 번 실행해야 생성됩니다.
    if (-not $wtPath) {
        $parent = $wtCandidates | Where-Object { Test-Path (Split-Path $_ -Parent) } | Select-Object -First 1
        if ($parent) {
            Write-Host '         설정 파일 생성을 위해 Windows Terminal 을 잠깐 실행합니다...' -ForegroundColor DarkGray
            Start-Process wt.exe -ArgumentList '-w', '_bootstrap', 'powershell', '-NoProfile', '-Command', 'exit'
            for ($i = 0; $i -lt 40 -and -not (Test-Path $parent); $i++) { Start-Sleep -Milliseconds 500 }
            Get-Process WindowsTerminal -ErrorAction Ignore | Stop-Process -Force
            if (Test-Path $parent) { $wtPath = $parent }
        }
    }

    if (-not $wtPath) {
        Warn 'Windows Terminal 설정 파일을 찾지 못했습니다. 터미널을 한 번 실행한 뒤 이 스크립트를 다시 돌리세요.'
    }
    else {
        Backup-File $wtPath

        # 템플릿(우리 설정)과 사용자의 기존 설정을 각각 읽어 병합합니다.
        # PS 5.1 의 Get-Content 는 UTF-8 파일을 ANSI 로 오독하므로 명시적으로 읽습니다.
        $tmpl = Join-Path $env:TEMP "win-iterm2-wt-$Stamp.json"
        Copy-Asset 'config/terminal-settings.json' $tmpl
        $T = [System.IO.File]::ReadAllText($tmpl, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $S = [System.IO.File]::ReadAllText($wtPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
        Remove-Item $tmpl -Force -ErrorAction Ignore

        # 6-1. 배색 추가 (이름이 겹치면 우리 것으로 교체)
        $existing = @()
        if ($S.PSObject.Properties['schemes'] -and $S.schemes) { $existing = @($S.schemes) }
        $ourNames = @($T.schemes.name)
        $merged = @($existing | Where-Object { $ourNames -notcontains $_.name }) + @($T.schemes)
        Set-Prop $S 'schemes' $merged
        Ok "배색 $($ourNames.Count)종 등록 ($($ourNames -join ', '))"

        # 6-2. 모든 프로필 공통 기본값
        $defaults = $T.profiles.defaults
        Set-Prop $defaults 'colorScheme' $Scheme
        Set-Prop $defaults 'opacity'     $Opacity
        $defaults.font.face = $FontFace
        $defaults.font.size = $FontSize
        Set-Prop $S.profiles 'defaults' $defaults
        Ok "폰트 $FontFace ${FontSize}pt / 배색 $Scheme / 투명도 $Opacity%"

        # 6-3. 단축키 (같은 id 가 이미 있으면 사용자 것을 존중)
        $kb = @()
        if ($S.PSObject.Properties['keybindings'] -and $S.keybindings) { $kb = @($S.keybindings) }
        $haveIds = @($kb | ForEach-Object { $_.id })
        $add = @($T.keybindings | Where-Object { $haveIds -notcontains $_.id })
        if ($add.Count) { Set-Prop $S 'keybindings' ($kb + $add); Ok "단축키 $($add.Count)개 추가" }
        else { Skip '단축키 변경 없음' }

        # 6-4. Git Bash 프로필 (설치되어 있고 아직 없을 때만)
        $gitBash = 'C:\Program Files\Git\bin\bash.exe'
        $list = @($S.profiles.list)
        if ((Test-Path $gitBash) -and -not ($list | Where-Object { $_.name -eq 'Git Bash' })) {
            $gb = $T.profiles.list | Where-Object { $_.name -eq 'Git Bash' }
            if ($gb) { Set-Prop $S.profiles 'list' ($list + $gb); $list = @($S.profiles.list); Ok 'Git Bash 프로필 추가' }
        }

        # 6-5. 기본 프로필을 PowerShell 7 로 — GUID 는 하드코딩하지 않고
        #      동적 프로필 source 로 찾습니다 (환경마다 다를 수 있음).
        $ps7 = $list | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
        if ($ps7) { Set-Prop $S 'defaultProfile' $ps7.guid; Ok "기본 프로필: $($ps7.name)" }
        else { Warn 'PowerShell 7 프로필을 찾지 못해 기본 프로필은 그대로 둡니다.' }

        # PS 5.1 의 ConvertTo-Json 은 비ASCII 를 \uXXXX 로 이스케이프하므로
        # 인코딩 사고 없이 안전합니다. Depth 를 반드시 올려야 합니다.
        $json = $S | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($wtPath, $json, (New-Object Text.UTF8Encoding($false)))
        Ok $wtPath
    }
}

# ── 7. 검증 ──────────────────────────────────────────────────
Step '검증'
$verify = @'
. $PROFILE
$r = [ordered]@{}
$r['프로필 로드'] = ($Error.Count -eq 0)
$r['프롬프트']    = [bool](Get-Command prompt -ErrorAction Ignore)
$r['아이콘']      = [bool](Get-Module Terminal-Icons)
$r['zoxide (z)']  = [bool](Get-Command z -ErrorAction Ignore)
$r['fzf']         = [bool](Get-Command fzf -ErrorAction Ignore)
$r.GetEnumerator() | ForEach-Object { "{0,-12} {1}" -f $_.Key, $(if ($_.Value) { 'OK' } else { 'FAIL' }) }
'@
$vp = Join-Path $env:TEMP "win-iterm2-verify-$Stamp.ps1"
[System.IO.File]::WriteAllText($vp, $verify, (New-Object Text.UTF8Encoding($true)))
pwsh -NoLogo -File $vp 2>&1 | ForEach-Object { Write-Host "    $_" }
Remove-Item $vp -Force -ErrorAction Ignore

Write-Host @"

  설치 완료.

  Windows Terminal 을 새로 열면 적용됩니다.
  배색 변경은  Ctrl+,  ->  프로필 -> 기본값 -> 모양 -> 색 구성표

  z <디렉터리 일부>   자주 가는 폴더로 점프
  Ctrl+R              퍼지 히스토리 검색
  Ctrl+T              현재 폴더 아래 파일 검색
  Ctrl+Shift+D / E    세로 / 가로 분할

"@ -ForegroundColor Green
