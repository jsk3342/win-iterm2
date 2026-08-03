# win-iterm2

맥 iTerm2 감성의 Windows 터미널 환경을 **명령 한 줄로** 구성합니다.
관리자 권한이 필요 없고, 여러 번 실행해도 안전합니다.

```powershell
irm https://raw.githubusercontent.com/USER/win-iterm2/main/install.ps1 | iex
```

설치가 끝나면 Windows Terminal 을 새로 열기만 하면 됩니다. **폰트를 수동으로 바꿀 필요가 없습니다.**

---

## 무엇이 설치되나

| 층 | 구성 요소 | 역할 |
|---|---|---|
| 터미널 | **Windows Terminal** | 트루컬러·투명도·탭·분할. "색이 구리다"의 실제 원인은 이 층입니다 |
| 셸 | **PowerShell 7** | 5.1 은 2016 년에 동결됐습니다 |
| 프롬프트 | **oh-my-posh** + 커스텀 테마 | 경로·git·node/python·실행시간 세그먼트 |
| 폰트 | **MesloLGM Nerd Font** | Meslo 는 macOS Menlo 파생. 아이콘 글리프 포함 |
| 이동 | **zoxide** | `z proj` 로 자주 가는 폴더 점프 |
| 검색 | **fzf** + PSFzf | `Ctrl+R` 퍼지 히스토리, `Ctrl+T` 파일 검색 |
| 목록 | **Terminal-Icons** | 파일 타입별 컬러 아이콘 |

배색은 **Snazzy**(기본), Tokyo Night Storm, Dracula, Nord 4종이 등록되며
`Ctrl+,` → 프로필 → 기본값 → 모양 에서 드롭다운으로 전환됩니다.

## 옵션

```powershell
# 리포를 클론한 경우
.\install.ps1 -Scheme 'Tokyo Night Storm' -Opacity 100 -FontSize 12

# 터미널 설정은 건드리지 않고 셸 환경만
.\install.ps1 -SkipTerminalSettings
```

| 파라미터 | 기본값 | 설명 |
|---|---|---|
| `-Scheme` | `Snazzy` | 배색 |
| `-Opacity` | `88` | 배경 투명도(%). `100` 이면 불투명 |
| `-FontSize` | `11` | 폰트 크기 |
| `-FontFace` | `MesloLGM Nerd Font` | 폰트 |
| `-SkipFont` | | 폰트 설치 건너뛰기 |
| `-SkipTerminalSettings` | | Windows Terminal 설정 건드리지 않기 |

## 단축키

| 키 | 동작 |
|---|---|
| `Ctrl+R` | 퍼지 히스토리 검색 (fzf) |
| `Ctrl+T` | 현재 폴더 아래 파일 검색 |
| `↑` `↓` | 입력한 접두사로 히스토리 검색 (zsh 스타일) |
| `Tab` | 메뉴형 자동완성 |
| `Ctrl+Shift+D` / `E` | 세로 / 가로 분할 |
| `Alt+방향키` | 분할된 창 사이 이동 |
| `Ctrl+Shift+F` | 검색 |

`z` `zi` `ll` `la` `..` `...` `which` `grep` `touch` `mkcd`
`ga` `gaa` `gst` `gd` `gco` `gcmsg` `gpsh` `gpll` `glog`

## 되돌리기

```powershell
.\uninstall.ps1
```

`install.ps1` 은 덮어쓰기 전에 항상 `<원본>.bak-<타임스탬프>` 를 남깁니다.
위 명령은 가장 최근 백업으로 복원합니다 (패키지·폰트는 지우지 않습니다).

---

## 기존 프로젝트와의 차이

가장 널리 쓰이는 [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile) 및
[jameswylde/powershell-windowsterminal-profile](https://github.com/jameswylde/powershell-windowsterminal-profile) 과 비교했습니다.

| | win-iterm2 | ChrisTitusTech | jameswylde |
|---|---|---|---|
| Windows Terminal 폰트/배색/투명도 자동 설정 | **O** | X (수동 안내) | 부분 |
| 관리자 권한 | **불필요** | 필요 | 필요 |
| 폰트 설치 범위 | 사용자 (`%LOCALAPPDATA%`) | 시스템 (`C:\Windows\Fonts`) | 시스템 |
| 기존 터미널 설정 | **병합 + 백업** | 건드리지 않음 | 덮어쓰기 |
| 프롬프트 테마 | 터미널 배색과 색 맞춤 | 기성 cobalt2 | 자체 테마 |
| 디렉터리 점프 | zoxide | zoxide | z (구형) |
| 퍼지 검색 (`Ctrl+R`) | **fzf** | X | X |
| 히스토리 비밀정보 차단 | O | O | X |

**가장 중요한 차이는 첫 줄입니다.** ChrisTitusTech 는 Nerd Font 를 설치만 하고
Windows Terminal 설정은 손대지 않습니다. 그래서 README 에 "설치 후 폰트를
CaskaydiaCove NF 로 직접 바꾸세요"라고 적혀 있고, 그 전까지 프롬프트 아이콘이
전부 두부(□)로 보입니다. 이 리포는 그 단계를 없앴습니다.

## 알아둘 함정

직접 고칠 때 걸릴 만한 것들입니다.

- **테마를 고쳤는데 반영이 안 될 때** — oh-my-posh v26+ 는 설정을 캐시합니다.
  `oh-my-posh cache clear` 를 실행하세요. 캐시가 살아 있으면 프롬프트에
  `CONFIG NOT FOUND` 가 그대로 뜹니다.
- **테마 JSON 을 편집할 때** — 구분자 글리프(``, U+E0B0)는 유니코드 사설 사용
  영역에 있습니다. 반드시 **UTF-8** 로 저장하세요. ANSI 로 저장하면 글리프가
  깨지면서 JSON 문자열까지 망가집니다.
- **PowerShell 5.1 에서 이 파일들을 읽을 때** — 5.1 의 `Get-Content` 는 BOM 없는
  UTF-8 을 ANSI 로 오독합니다. `[System.IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)`
  를 쓰세요.
- **winget 설치 직후 `zoxide` 를 못 찾을 때** — PATH 가 현재 세션에 반영되지
  않아서입니다. 터미널을 새로 열거나 레지스트리에서 PATH 를 다시 읽으세요.

## 요구 사항

- Windows 10 1809 이상 / Windows 11
- `winget` (Microsoft Store 의 "앱 설치 관리자")

## 라이선스

MIT
