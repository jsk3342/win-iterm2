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
    irm https://raw.githubusercontent.com/jsk3342/win-iterm2/main/get.ps1 | iex

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

    [string]$Repo = 'jsk3342/win-iterm2',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 의 진행 막대는 한국어 콘솔에서 화면을 저장하다 IndexOutOfRangeException 을 낼 수 있고,
# 위의 Stop 때문에 설치 전체가 끊깁니다. 단계는 글로 보여 주므로 막대를 쓰지 않습니다.
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# ─────────────────────────── 출력 헬퍼 ───────────────────────────
$script:StepNo = 0
$script:StepLabel = '시작 전'
$script:Problems = @()
$script:Stopwatch = [Diagnostics.Stopwatch]::StartNew()
$script:Heartbeat = $null

# winget·글꼴 내려받기는 출력을 버려서 멈춘 것처럼 보입니다. 15초마다 경과 시간을 찍습니다.
function Stop-StepHeartbeat {
    if ($null -ne $script:Heartbeat) {
        $script:Heartbeat.Stop()
        $script:Heartbeat.Dispose()
        $script:Heartbeat = $null
    }
}
function Start-StepHeartbeat {
    Stop-StepHeartbeat
    $hb = [powershell]::Create()
    $null = $hb.AddScript({
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while ($watch.Elapsed.TotalMinutes -lt 60) {
            Start-Sleep -Seconds 15
            # 다른 프로그램이 줄을 끝내지 않은 채 쓰는 중이면 줄을 바꿔 글이 이어 붙지 않게 합니다.
            try { if ([Console]::CursorLeft -gt 0) { [Console]::WriteLine() } } catch { }
            [Console]::WriteLine("         설치 작업 실행 중 · 경과 $([int]$watch.Elapsed.TotalSeconds)초 · 완료 문구를 기다려주세요.")
        }
    })
    $null = $hb.BeginInvoke()
    $script:Heartbeat = $hb
}

# 끊기거나 일부만 끝나면 고객이 여러 번 나눠 붙여넣지 않도록 진단 내용을 한 덩어리로 보여 줍니다.
function Write-FailureReport($result, $message) {
    $safe = [string]$message
    if ($env:USERPROFILE) { $safe = $safe.Replace($env:USERPROFILE, '~') }
    $safe = $safe -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
    $safe = ($safe -replace '\s+', ' ').Trim()
    if ($safe.Length -gt 800) { $safe = $safe.Substring(0, 800) + ' ...' }
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $width = try { $Host.UI.RawUI.BufferSize.Width } catch { '알 수 없음' }
    $report = @(
        '---------- 설치 실패 보고 시작 ----------'
        '설치기: win-iterm2 (터미널 꾸미기)'
        "결과: $result"
        "단계: $script:StepLabel"
        "오류: $safe"
        "걸린 시간: $([int]$script:Stopwatch.Elapsed.TotalSeconds)초"
        "OS: Windows $([Environment]::OSVersion.Version)"
        "칩: $env:PROCESSOR_ARCHITECTURE"
        "PowerShell: $($PSVersionTable.PSVersion) / 코드페이지 $([Console]::OutputEncoding.CodePage) / 창 폭 $width / 관리자 $isAdmin"
        '---------- 설치 실패 보고 끝 ----------'
    ) -join "`r`n"
    Write-Host ''
    Write-Host $report
    $copied = $false
    try {
        Set-Clipboard -Value $report
        $copied = ((Get-Clipboard -Raw).Trim() -eq $report.Trim())
    }
    catch { $copied = $false }
    if ($copied) { Write-Host '  위 보고를 복사해 두었습니다. 설치 도우미 입력칸에 그대로 붙여넣어 주세요.' -ForegroundColor Yellow }
    else { Write-Host '  위 보고를 시작 줄부터 끝 줄까지 복사해 설치 도우미 입력칸에 붙여넣어 주세요.' -ForegroundColor Yellow }
}

function Step($msg) {
    $script:StepNo++
    $script:StepLabel = "$script:StepNo/7 $msg"
    Start-StepHeartbeat
    Write-Host "`n[$script:StepNo] $msg" -ForegroundColor Cyan
}
function Ok($msg) { Write-Host "    OK   $msg" -ForegroundColor Green }
function Skip($msg) { Write-Host "    --   $msg" -ForegroundColor DarkGray }
function Warn($msg) { $script:Problems += "[$script:StepLabel] $msg"; Write-Host "    !    $msg" -ForegroundColor Yellow }

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
`$ProgressPreference = 'SilentlyContinue'
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
Install-Module $name -Scope CurrentUser -Force -AllowClobber -AcceptLicense
"@ | Out-Null
    Ok "$name 설치됨"
}

# 글꼴이 실제로 깔렸는지 봅니다. 설치 프로그램의 종료 코드만 믿으면 안 됩니다
# (옵션이 사라져 설치를 안 하거나, 파일별 실패를 삼키고 0 으로 끝난 적이 있습니다).
# GDI+ 목록은 방금 설치한 글꼴을 놓칠 수 있어 레지스트리 등록과 파일도 함께 봅니다.
function Test-FontInstalled($face) {
    Add-Type -AssemblyName System.Drawing
    $families = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($families -contains $face) { return $true }

    $pattern = '^' + [regex]::Escape($face) + '( Regular)? \((TrueType|OpenType)\)$'
    foreach ($key in 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                     'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
        $entries = Get-ItemProperty -Path $key -ErrorAction Ignore
        if (-not $entries) { continue }
        foreach ($prop in $entries.PSObject.Properties) {
            if ($prop.Name -notmatch $pattern) { continue }
            $file = [string]$prop.Value
            if (-not [IO.Path]::IsPathRooted($file)) { $file = Join-Path $env:WINDIR "Fonts\$file" }
            if (Test-Path -LiteralPath $file) { return $true }
        }
    }
    return $false
}

# 돌려주는 값 = 터미널 설정에 이 글꼴 이름을 넣어도 되는가.
function Install-NerdFont($face) {
    if (Test-FontInstalled $face) { Skip "$face 이미 설치됨"; return $true }

    $detail = ''
    try {
        # 사용자 범위(%LOCALAPPDATA%)에 설치 — 관리자 권한 불필요
        # 이름(meslo) 대신 주소를 줍니다. 이름은 GitHub API 로 찾는데, 같은 IP 를 나눠 쓰면
        # 비로그인 호출 한도에 걸려 실패합니다(CI 에서 실측). 주소는 그 조회를 건너뜁니다.
        # 출력은 버립니다. 파이프로 받으면 한글 윈도우에서 진행 글자가 깨지고, 반환값에도 섞입니다.
        # 성공 여부는 아래에서 글꼴을 직접 확인합니다.
        Write-Host "         $face 내려받는 중 (약 120MB)..." -ForegroundColor DarkGray
        oh-my-posh font install 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip' | Out-Null
        $detail = "exit $LASTEXITCODE"
    }
    catch { $detail = $_.Exception.Message }

    if (Test-FontInstalled $face) { Ok "$face 설치됨"; return $true }
    Warn "$face 를 설치하지 못했습니다 ($detail). 터미널은 기본 글꼴로 둡니다."
    return $false
}

# 터미널 설정에 넣을 글꼴 이름. $null = face 를 비워 터미널 기본 글꼴을 씁니다.
# 없는 글꼴 이름이 설정에 있으면 터미널을 열 때마다 경고창이 뜨므로,
# 예전 실행이 넣어 둔 같은 이름도 함께 걷어냅니다. 사용자가 고른 다른 글꼴은 그대로 둡니다.
function Resolve-FontFace($face, [bool]$fontReady, $currentFace) {
    if ($fontReady) { return $face }
    if ($currentFace -and $currentFace -ne $face) { return $currentFace }
    return $null
}

# 한글은 2칸으로 세어 왼쪽 정렬합니다. 그래야 뒤 칸의 세로줄이 맞습니다.
function Format-VerifyLine($label, $result) {
    $width = 0
    foreach ($c in $label.ToCharArray()) { $width += $(if ([int]$c -gt 127) { 2 } else { 1 }) }
    return ($label + (' ' * [Math]::Max(1, 14 - $width)) + $result)
}

# PS 5.1 turns redirected native stderr into terminating errors under Stop.
# Capture both streams independently, in UTF-8, before deciding whether the child failed.
function Invoke-PwshFile([string]$Path) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $info.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $Path + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw 'PowerShell verification timed out after 60 seconds.'
        }
        return @{ ExitCode = $process.ExitCode; Output = $stdout.Result; Error = $stderr.Result }
    }
    finally { $process.Dispose() }
}

function Resolve-PwshProfile {
    $path = Join-Path $env:TEMP ("win-iterm2-profile-" + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        [IO.File]::WriteAllText($path, '[Console]::OutputEncoding = [Text.Encoding]::UTF8; $PROFILE.CurrentUserCurrentHost', (New-Object Text.UTF8Encoding($true)))
        $result = Invoke-PwshFile $path
        $profilePath = $result.Output.Trim()
        if ($result.ExitCode -ne 0 -or -not [IO.Path]::IsPathRooted($profilePath)) {
            throw "Cannot resolve PowerShell 7 profile: $($result.Error)"
        }
        return $profilePath
    }
    finally { Remove-Item $path -Force -ErrorAction Ignore }
}

# 새 프로필이 PowerShell 7 에서 실제로 동작하는지 확인합니다.
# 파이프로 넘어오는 pwsh 출력은 UTF-8 인데 PS 5.1 은 콘솔 코드페이지(한글 윈도우는 CP949)로
# 읽습니다. 그래서 자식은 ASCII 코드만 내보내고, 한글 이름은 여기서 붙입니다.
function Invoke-InstallVerify {
    $verify = @'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
try { . $PROFILE }
catch {
    [Console]::Error.WriteLine(($_ | Format-List * -Force | Out-String))
    exit 1
}
$r = [ordered]@{}
$r['profile'] = ($Error.Count -eq 0)
$r['prompt']  = [bool](Get-Command prompt -ErrorAction Ignore)
$r['icons']   = [bool](Get-Module Terminal-Icons)
$r['zoxide']  = [bool](Get-Command z -ErrorAction Ignore)
$r['fzf']     = [bool](Get-Command fzf -ErrorAction Ignore)
$r.GetEnumerator() | ForEach-Object { "CHECK {0} {1}" -f $_.Key, $(if ($_.Value) { 'OK' } else { 'FAIL' }) }
'@
    $labels = @{
        profile = '프로필 로드'
        prompt  = '프롬프트'
        icons   = '아이콘'
        zoxide  = 'zoxide (z)'
        fzf     = 'fzf'
    }
    $vp = Join-Path $env:TEMP "win-iterm2-verify-$Stamp.ps1"
    [System.IO.File]::WriteAllText($vp, $verify, (New-Object Text.UTF8Encoding($true)))
    try {
        $result = Invoke-PwshFile $vp
        $seen = @{}
        foreach ($line in ($result.Output -split '\r?\n')) {
            if ($line -match '^CHECK (\w+) (OK|FAIL)$' -and $labels.ContainsKey($Matches[1])) {
                $seen[$Matches[1]] = $true
                if ($Matches[2] -eq 'FAIL') { $script:Problems += "[$script:StepLabel] 검증 실패: $($labels[$Matches[1]])" }
                Write-Host "    $(Format-VerifyLine $labels[$Matches[1]] $Matches[2])"
            }
            elseif ($line) { Write-Host "    $line" }
        }
        if ($result.ExitCode -ne 0 -or $result.Error.Trim()) {
            throw "PowerShell profile verification failed (exit $($result.ExitCode)): $($result.Error.Trim()) $($result.Output.Trim())"
        }
        if ($seen.Count -ne $labels.Count) { throw 'PowerShell verification did not return all five checks.' }
    }
    finally { Remove-Item $vp -Force -ErrorAction Ignore }
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

# 어떤 이유로 끊겨도 경과 표시를 멈추고 실패 보고를 남깁니다. 들여쓰기는 바꾸지 않습니다.
try {

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
$script:FontReady = $true   # -SkipFont = 글꼴은 사용자가 책임진다는 뜻
if ($SkipFont) {
    Skip '-SkipFont 지정됨'
}
else {
    $script:FontReady = Install-NerdFont $FontFace
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
$pwshProfile = Resolve-PwshProfile
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
        $defaults.font.size = $FontSize
        $face = Resolve-FontFace $FontFace $script:FontReady $S.profiles.defaults.font.face
        if ($face) { $defaults.font.face = $face }
        else { $defaults.font.PSObject.Properties.Remove('face') }
        Set-Prop $S.profiles 'defaults' $defaults
        $faceLabel = if ($face) { $face } else { '터미널 기본 글꼴' }
        Ok "폰트 $faceLabel ${FontSize}pt / 배색 $Scheme / 투명도 $Opacity%"

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
        # 터미널을 한 번 열면 생기는 프로필이라 실패가 아닙니다. 실패 보고에 넣지 않습니다.
        else { Write-Host '    !    PowerShell 7 프로필을 찾지 못해 기본 프로필은 그대로 둡니다.' -ForegroundColor Yellow }

        # PS 5.1 의 ConvertTo-Json 은 비ASCII 를 \uXXXX 로 이스케이프하므로
        # 인코딩 사고 없이 안전합니다. Depth 를 반드시 올려야 합니다.
        $json = $S | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($wtPath, $json, (New-Object Text.UTF8Encoding($false)))
        Ok $wtPath
    }
}

# ── 7. 검증 ──────────────────────────────────────────────────
Step '검증'
Invoke-InstallVerify
Stop-StepHeartbeat

Write-Host @"

  설치 완료.

  Windows Terminal 창을 전부 닫고 새로 열면 적용됩니다.
  (열려 있던 창에는 글꼴 경고가 뜰 수 있어요. 새로 열면 사라집니다.)
  배색 변경은  Ctrl+,  ->  프로필 -> 기본값 -> 모양 -> 색 구성표

  z <디렉터리 일부>   자주 가는 폴더로 점프
  Ctrl+R              퍼지 히스토리 검색
  Ctrl+T              현재 폴더 아래 파일 검색
  Ctrl+Shift+D / E    세로 / 가로 분할

"@ -ForegroundColor Green

if (-not $script:FontReady) {
    Write-Host @"
  글꼴만 설치하지 못했습니다. 터미널과 클로드 코드는 그대로 쓸 수 있고,
  프롬프트 아이콘이 네모로 보일 수 있습니다. 인터넷 연결을 확인한 뒤 이 설치를 한 번 더 실행하세요.

"@ -ForegroundColor Yellow
}

if ($script:Problems.Count) {
    # 문제마다 어느 단계인지 붙어 있어, 마지막 단계 이름을 적으면 오히려 헷갈립니다.
    $script:StepLabel = '끝까지 진행함'
    Write-FailureReport '일부 미완료' ($script:Problems -join ' / ')
}

}
catch {
    Stop-StepHeartbeat
    Write-FailureReport '중단됨' $_.Exception.Message
    throw
}
finally {
    Stop-StepHeartbeat
}
