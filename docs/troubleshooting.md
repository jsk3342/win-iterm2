# 문제 해결

여기 적힌 것은 전부 **이 리포를 만들면서 실제로 밟은 지뢰**입니다.
`install.ps1`은 이들을 자동으로 처리하지만, 설정을 직접 고칠 때 다시 만나게 됩니다.

---

## 프롬프트에 `CONFIG NOT FOUND` 가 뜬다

**증상** — 테마 파일은 멀쩡한데 프롬프트가 기본 테마로 나오고 `CONFIG NOT FOUND`
세그먼트가 붙어 있음. JSON을 검사해도 유효함.

**원인** — oh-my-posh v26+ 는 설정을 캐시합니다. 캐시가 살아 있으면 `--config`로 넘긴
새 경로가 무시됩니다. **파일 문제가 아니라 캐시 문제입니다.**

**해결**

```powershell
oh-my-posh cache clear
```

테마 JSON을 손으로 고쳤는데 반영이 안 될 때도 같은 명령입니다.

---

## 프롬프트가 두부(□) 행렬로 나온다

**증상** — 구분자와 아이콘 자리에 네모 상자만 보임.

**원인 A — 폰트 미설치.** 글리프가 유니코드 사설 사용 영역(U+E0B0 등)에 있어서
일반 폰트에는 그 자리가 비어 있습니다. ([원리](how-it-works.md#4층--폰트-장식이-아니라-필수))

```powershell
oh-my-posh font install meslo --headless
```

**원인 B — 폰트는 깔았는데 터미널이 안 쓴다.** 이게 더 흔합니다.
`Ctrl+,` → 프로필 → 기본값 → 모양 → 글꼴에서 `MesloLGM Nerd Font` 확인.

설치된 폰트 이름을 정확히 확인하려면:

```powershell
Add-Type -AssemblyName System.Drawing
(New-Object System.Drawing.Text.InstalledFontCollection).Families |
    Where-Object Name -like "*Nerd*" | Select-Object -ExpandProperty Name
```

> `MesloLGM` / `MesloLGS` / `MesloLGL` 은 줄간격만 다른 변형입니다.
> `Mono` / `Propo` 접미사가 붙은 것은 글리프 폭 처리가 달라 프롬프트가 어긋날 수 있으니
> 접미사 없는 것을 쓰세요.

---

## 테마 JSON을 고쳤더니 프롬프트가 깨졌다

**증상** — 편집기로 테마를 저장한 뒤 프롬프트가 망가지거나 `CONFIG NOT FOUND`.

**원인** — 구분자 글리프(``, U+E0B0)는 UTF-8에서 3바이트입니다.
편집기가 **ANSI(CP949)로 저장하면** 글리프가 `?`로 치환되면서 **JSON 문자열의
닫는 따옴표까지 먹어버립니다.** 결과적으로 JSON 자체가 깨집니다.

```json
"leading_diamond": "",     ← 정상
"leading_diamond": "??,      ← ANSI 저장으로 깨진 상태 (따옴표 소실)
```

**해결** — 반드시 **UTF-8**로 저장하세요. VS Code라면 우하단 인코딩 표시를 확인하세요.

**검증**

```powershell
$p = "$HOME\.config\oh-my-posh\snazzy.omp.json"
[System.IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) | ConvertFrom-Json | Out-Null
"OK"
```

---

## PowerShell 5.1에서 JSON을 읽으면 깨져 보인다

**증상** — 파일은 멀쩡한데 `Get-Content ... | ConvertFrom-Json` 이 파싱 오류를 냄.
오류 메시지 안의 내용이 `??` 투성이.

**원인** — PS 5.1의 `Get-Content`는 **BOM 없는 UTF-8을 ANSI로 오독**합니다.
파일이 아니라 **읽는 쪽 문제**입니다. PowerShell 7에서는 정상입니다.

**해결** — 인코딩을 명시해서 읽으세요.

```powershell
[System.IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
```

같은 이유로 `install.ps1`과 `uninstall.ps1`에는 **UTF-8 BOM**이 붙어 있습니다.
BOM을 떼면 PS 5.1에서 한글 메시지가 깨집니다. 편집 후 저장할 때 주의하세요.

---

## 설치했는데 `zoxide` / `fzf` 를 못 찾는다

**증상** — winget이 "설치 성공"이라고 했는데 `z`나 `fzf`가 인식되지 않음.

**원인** — winget이 PATH에 추가한 내용이 **현재 세션에 반영되지 않았습니다.**
프로세스의 환경 변수는 시작할 때 복사된 스냅샷이라 나중에 바뀌어도 갱신되지 않습니다.

**해결 A** — 터미널을 새로 엽니다 (가장 간단).

**해결 B** — 세션 PATH를 레지스트리에서 다시 읽습니다.

```powershell
$env:Path = ([Environment]::GetEnvironmentVariable('Path','Machine'),
             [Environment]::GetEnvironmentVariable('Path','User')) -join ';'
```

`install.ps1`은 패키지 설치마다 이 작업을 합니다.

---

## `Ctrl+R` 이 fzf가 아니라 기본 검색으로 뜬다

**원인 A** — PSFzf 로드 순서. PSFzf가 PSReadLine의 키 바인딩을 가로채므로
**PSReadLine 설정보다 뒤에** 와야 합니다. 프로필에서 순서를 확인하세요.

**원인 B** — `fzf` 실행 파일이 PATH에 없음 (위 항목 참고).
프로필은 `fzf`가 없으면 조용히 건너뛰도록 되어 있습니다.

**확인**

```powershell
Get-Command fzf
Get-Module PSFzf
```

---

## 비대화형 실행에서 PSReadLine 오류가 쏟아진다

**증상**

```
The predictive suggestion feature cannot be enabled because the console output
doesn't support virtual terminal processing or it's redirected.
```

**원인** — 예측 기능은 가상 터미널이 필요합니다. `pwsh -Command ... | Out-String`처럼
출력이 리다이렉트된 상태에서 프로필이 로드되면 실패합니다. **대화형 사용에는 문제가
없습니다.**

**해결** — 프로필이 이미 가드하고 있습니다.

```powershell
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}
```

---

## `$Error`에 항목이 쌓인다

**원인** — `-ErrorAction SilentlyContinue`는 화면 **출력만** 막고 `$Error`에는
그대로 쌓입니다. 프로필에서 `Get-Command`로 도구 존재를 확인하면 없는 도구마다
오류가 누적됩니다.

**해결** — 존재 확인 용도로는 `-ErrorAction Ignore`를 쓰세요. `$Error`에 남지 않습니다.

---

## Windows Terminal 설정 파일을 못 찾는다

설치 방식에 따라 경로가 다릅니다.

| 배포 | 경로 |
|---|---|
| Store / winget | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| Preview | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json` |
| 비패키지 (Scoop/Chocolatey/zip) | `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json` |

`install.ps1`은 이 셋을 순서대로 탐색합니다.

**설치 직후에는 파일이 아직 없습니다.** Windows Terminal을 한 번 실행해야 생성됩니다.
스크립트는 이 경우 터미널을 잠깐 띄웠다 닫아서 생성을 유도합니다.

> 프로필 GUID는 하드코딩하지 마세요. PowerShell 7 프로필의 GUID는 환경에 따라 다를
> 수 있습니다. `source`가 `Windows.Terminal.PowershellCore`인 항목을 찾는 방식이
> 안전합니다 — `install.ps1`이 그렇게 합니다.

---

## 되돌리고 싶다

```powershell
.\uninstall.ps1
```

`install.ps1`은 덮어쓰기 전에 항상 `<원본>.bak-<타임스탬프>`를 남깁니다.
위 명령은 가장 최근 백업으로 복원합니다.

패키지와 폰트는 지우지 않습니다. 필요하면 직접:

```powershell
winget uninstall JanDeDobbeleer.OhMyPosh
winget uninstall ajeetdsouza.zoxide
winget uninstall junegunn.fzf
```
