# ─────────────────────────────────────────────────────────────
#  win-iterm2 : PowerShell 7 프로필
#  https://github.com/jsk3342/win-iterm2
# ─────────────────────────────────────────────────────────────

# ── 프롬프트 (oh-my-posh) ────────────────────────────────────
$OmpTheme = "$HOME\.config\oh-my-posh\snazzy.omp.json"
if ((Get-Command oh-my-posh -ErrorAction Ignore) -and (Test-Path $OmpTheme)) {
    oh-my-posh init pwsh --config $OmpTheme | Invoke-Expression
}

# ── 파일 아이콘 (Nerd Font 필요) ─────────────────────────────
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# ── PSReadLine ───────────────────────────────────────────────
Import-Module PSReadLine

Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -BellStyle None

# 비밀정보가 히스토리 파일에 남지 않도록 차단
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = 'password', 'passwd', 'secret', 'token', 'apikey', 'api_key',
                 'connectionstring', 'credential', 'private_key', '-AsPlainText'
    foreach ($p in $sensitive) { if ($line -match [regex]::Escape($p)) { return $false } }
    return $true
}

# 예측 기능은 가상 터미널이 필요 — 리다이렉트된 비대화형 실행에서는 건너뜀
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}

# Snazzy 팔레트에 맞춘 구문 강조
Set-PSReadLineOption -Colors @{
    Command          = '#57C7FF'
    Parameter        = '#FF6AC1'
    Operator         = '#FF6AC1'
    Variable         = '#F3F99D'
    String           = '#5AF78E'
    Number           = '#FF5C57'
    Type             = '#9AEDFE'
    Comment          = '#686868'
    Keyword          = '#FF6AC1'
    Error            = '#FF5C57'
    InlinePrediction = '#686868'
    ListPrediction   = '#686868'
}

# 화살표 위/아래 = 입력한 접두사로 히스토리 검색 (zsh 스타일)
Set-PSReadLineKeyHandler -Key UpArrow        -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow      -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab            -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+w         -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

# ── fzf: Ctrl+R 퍼지 히스토리, Ctrl+T 파일 검색 ──────────────
# PSFzf가 PSReadLine 키를 가로채므로 PSReadLine 설정 뒤에 와야 함
if ((Get-Command fzf -ErrorAction Ignore) -and
    (Get-Module -ListAvailable -Name PSFzf) -and
    (-not [Console]::IsOutputRedirected)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border ' +
        '--color=bg+:#3A3D4D,fg+:#EFF0EB,hl:#FF6AC1,hl+:#FF6AC1,' +
        'info:#57C7FF,prompt:#5AF78E,pointer:#FF6AC1,marker:#F3F99D'
}

# ── zoxide: 자주 가는 디렉터리로 점프 (z <일부이름>) ─────────
if (Get-Command zoxide -ErrorAction Ignore) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── macOS/zsh 습관용 별칭 ────────────────────────────────────
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function which ($cmd) { (Get-Command $cmd -ErrorAction SilentlyContinue).Source }
function grep { $input | Select-String @args }
function touch ($f) {
    if (Test-Path $f) { (Get-Item $f).LastWriteTime = Get-Date }
    else { New-Item -ItemType File $f | Out-Null }
}
function mkcd ($d) { New-Item -ItemType Directory -Force $d | Out-Null; Set-Location $d }

# git 단축 — PowerShell 기본 별칭(gc=Get-Content, gp=Get-ItemProperty,
# gl=Get-Location)을 가리지 않는 이름만 사용
function ga   { git add @args }
function gaa  { git add --all }
function gst  { git status }
function gd   { git diff @args }
function gco  { git checkout @args }
function gcmsg { git commit -m @args }
function gpsh { git push @args }
function gpll { git pull @args }
function glog { git log --oneline --graph --decorate -20 @args }

# UTF-8 (한글 깨짐 방지)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8