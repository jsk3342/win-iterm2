# 다른 프로젝트와의 비교

> 이 리포를 만들기 전에 기존 프로젝트를 조사하고 실제 소스를 읽었습니다.
> 이 문서는 **어디를 베끼고 어디를 다르게 했는지, 그리고 왜인지**를 남깁니다.

## 조사 대상

| 프로젝트 | 성격 |
|---|---|
| [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile) | 이 분야에서 가장 유명. `irm ... \| iex` 한 줄 설치 |
| [jameswylde/powershell-windowsterminal-profile](https://github.com/jameswylde/powershell-windowsterminal-profile) | Windows Terminal 설정까지 포함 |
| [Scott Hanselman의 글](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal) | 이 스택을 대중화시킨 원조 격 |

## 대조표

| | **win-iterm2** | ChrisTitusTech | jameswylde |
|---|---|---|---|
| Windows Terminal 폰트/배색/투명도 자동 설정 | **O** | **X** (수동 안내) | 부분 |
| 관리자 권한 | **불필요** | 필요 | 필요 |
| 폰트 설치 범위 | 사용자 (`%LOCALAPPDATA%`) | 시스템 (`C:\Windows\Fonts`) | 시스템 |
| 기존 터미널 설정 | **병합 + 백업** | 건드리지 않음 | 덮어쓰기 |
| 프롬프트 테마 | 터미널 배색과 색 맞춤 | 기성 cobalt2 | 자체 테마 |
| 디렉터리 점프 | zoxide | zoxide | z (구형) |
| 퍼지 검색 (`Ctrl+R`) | **fzf + PSFzf** | X | X |
| 히스토리 비밀정보 차단 | O | O | X |
| 기본 별칭 오염 (`gc`/`gp`/`gl`) | **없음** | 있음 | 없음 |

---

## 우리가 다르게 한 것

### 1. Windows Terminal 설정까지 건드린다 — 가장 큰 차이

ChrisTitusTech는 Nerd Font를 **설치만 하고** Windows Terminal 설정은 손대지 않습니다.
그래서 README에 이런 안내가 있습니다:

> "After installing, restart Windows Terminal and set your PowerShell font to CaskaydiaCove NF."

[4층 구조](how-it-works.md#4층--폰트-장식이-아니라-필수)에서 설명했듯, **1층(터미널)이
그 폰트를 쓰도록 설정되지 않으면 4층(폰트)은 무용지물**입니다. 수동으로 바꾸기 전까지
프롬프트 아이콘이 전부 두부(□)로 보입니다.

이 리포는 그 단계를 없앴습니다. 설치 후 터미널만 새로 열면 끝입니다.

### 2. 관리자 권한을 요구하지 않는다

ChrisTitusTech는 `Test-IsAdministrator` 체크로 시작하고, 폰트를 `C:\Windows\Fonts`에
시스템 설치합니다.

이 리포는 `oh-my-posh font install meslo --headless`로 **사용자 범위**
(`%LOCALAPPDATA%\Microsoft\Windows\Fonts`)에 설치하고, winget도 사용자 범위로 씁니다.
회사 PC처럼 관리자 권한이 없는 환경에서도 돌아갑니다.

### 3. 기존 설정을 덮어쓰지 않고 병합한다

이미 자기 취향대로 꾸며둔 사람의 설정을 날리면 안 됩니다.
병합 로직은 다음을 보장합니다:

- 사용자의 커스텀 배색·프로필은 그대로 유지, 우리 것을 **추가**
- 같은 `id`의 단축키가 이미 있으면 **사용자 것을 존중** (덮어쓰지 않음)
- `launchMode` 같은 우리가 안 쓰는 설정은 손대지 않음
- 덮어쓰기 전 항상 `<원본>.bak-<타임스탬프>` 백업

실제로 검증했습니다. 커스텀 배색 + WSL 프로필 + `Ctrl+Shift+C` 복사 키 +
`launchMode: maximized`를 가진 가짜 설정에 설치를 돌린 결과, 넷 다 살아남았고
복사 키도 우리 것(`Ctrl+C`)으로 덮이지 않았습니다.

### 4. 기본 별칭을 가리지 않는 git 단축을 쓴다

ChrisTitusTech의 프로필은 `gc`, `gp`, `gl`을 git 단축으로 정의합니다.
그런데 이들은 PowerShell **기본 별칭**입니다:

| 별칭 | 원래 명령 |
|---|---|
| `gc` | `Get-Content` |
| `gp` | `Get-ItemProperty` |
| `gl` | `Get-Location` |

가려버리면 인터넷에서 복사해온 스크립트가 조용히 깨질 수 있습니다.
이 리포는 충돌하지 않는 이름만 씁니다:

```
ga  gaa  gst  gd  gco  gcmsg  gpsh  gpll  glog
```

### 5. 프롬프트 색을 터미널 배색에 맞춘다

기성 테마(cobalt2 등)를 그대로 쓰면 프롬프트 색과 터미널 배색이 따로 놉니다.
이 리포의 [`snazzy.omp.json`](../config/snazzy.omp.json)은 Snazzy 팔레트의
정확한 헥스값을 씁니다 — PSReadLine 구문 강조와 fzf 색까지 같은 팔레트입니다.

```
#FF6AC1 핑크    #57C7FF 시안    #5AF78E 초록
#F3F99D 노랑    #FF5C57 빨강    #282A36 배경
```

---

## 우리가 배워온 것

조사 결과 **명백히 우리가 뒤졌던 것**들입니다. 전부 반영했습니다.

| 가져온 것 | 출처 | 왜 필요한가 |
|---|---|---|
| **[zoxide](https://github.com/ajeetdsouza/zoxide)** | 양쪽 다 | 맥 zsh의 `z`. `z proj` 로 자주 가는 폴더 점프. Rust로 작성돼 셸 시작을 늦추지 않음 |
| **[fzf](https://github.com/junegunn/fzf) + [PSFzf](https://github.com/kelleyma49/PSFzf)** | 어느 쪽에도 없었음 | iTerm2 쓰는 사람이 가장 많이 쓰는 `Ctrl+R` 퍼지 히스토리. 이게 빠지면 "맥처럼"이 안 됨 |
| 히스토리 비밀정보 차단 | ChrisTitusTech | `export API_KEY=...` 가 히스토리 파일에 평문으로 남는 걸 막음 |
| `HistoryNoDuplicates` | ChrisTitusTech | 같은 명령이 히스토리를 도배하는 것 방지 |
| git 단축 함수 | ChrisTitusTech | (이름만 바꿔서 채택 — 위 4번) |

`z` 모듈 대신 zoxide를 고른 이유는, `z`는 bash 스크립트를 PowerShell로 포팅한 구형이고
zoxide가 현재 사실상의 표준이기 때문입니다. 모든 주요 셸을 지원해서 나중에 WSL이나
맥으로 설정을 옮길 때도 그대로 씁니다.

---

## 아직 안 넣은 것

일부러 뺐습니다. 필요하면 프로필에 직접 추가하세요.

| 항목 | 뺀 이유 |
|---|---|
| `Update-Profile` / 자가 업데이트 | 매 셸 시작마다 네트워크를 치면 느려짐. `git pull` 후 재실행이 명확함 |
| MOTD / 시스템 정보 배너 | 셸 시작이 눈에 띄게 느려짐 |
| posh-git | oh-my-posh의 git 세그먼트와 기능이 겹침 |
| `Enable-PsFzfAliases` | `fd`, `fh` 등이 다른 도구와 충돌할 수 있음. 키 바인딩만 켬 |

---

## 참고

- [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile) — [setup.ps1](https://github.com/ChrisTitusTech/powershell-profile/blob/main/setup.ps1)
- [jameswylde/powershell-windowsterminal-profile](https://github.com/jameswylde/powershell-windowsterminal-profile)
- [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)
- [kelleyma49/PSFzf](https://github.com/kelleyma49/PSFzf)
- [Scott Hanselman — My Ultimate PowerShell prompt](https://www.hanselman.com/blog/my-ultimate-powershell-prompt-with-oh-my-posh-and-the-windows-terminal)
- [oh-my-posh 공식 문서](https://ohmyposh.dev)
