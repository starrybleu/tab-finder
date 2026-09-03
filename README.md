# Tab Finder

Tab Finder는 현재 열려 있는 Safari 창의 탭을 제목과 URL로 검색하고, 선택한 탭이 있는 창을 앞으로 가져오는 개인용 macOS 메뉴 막대 앱입니다.

## 요구 사항

- macOS 14 이상
- Safari
- Xcode 26 또는 Swift 6 호환 도구 모음
- Apple Developer Program 유료 계정은 필요하지 않습니다. 빌드 스크립트가 로컬 사용을 위해 앱을 ad-hoc 서명합니다.

## 빌드 및 설치

프로젝트 루트에서 다음을 실행합니다.

```bash
./scripts/build-app.sh
ditto "outputs/Tab Finder.app" "/Applications/Tab Finder.app"
open "/Applications/Tab Finder.app"
```

앱은 Dock에 나타나지 않고 시스템 메뉴 막대에 탭 검색 아이콘으로 표시됩니다. 빌드 결과는 `outputs/Tab Finder.app`입니다.

## 처음 실행할 때

1. Safari를 실행하고 탭을 하나 이상 엽니다.
2. 메뉴 막대의 Tab Finder 아이콘을 누릅니다.
3. macOS가 Safari 제어 권한을 요청하면 허용합니다.

권한 요청을 거절했다면 **시스템 설정 > 개인정보 보호 및 보안 > 자동화**에서 Tab Finder의 Safari 접근을 켜고 다시 시도하세요. Tab Finder는 Safari가 실행 중이지 않을 때 Safari를 임의로 실행하지 않습니다. 화면의 **Safari 열기** 버튼을 누를 때만 실행합니다.

## 사용법

- 검색창에 제목이나 URL 일부를 입력합니다. 여러 단어는 모두 포함된 탭만 찾습니다.
- `↑`와 `↓`로 결과를 선택하고 `Return`으로 엽니다. `Escape`는 팝오버를 닫습니다.
- 기본 전역 단축키는 물리 키 기준 `Command + Shift + '`입니다.
- 팝오버의 메뉴에서 **설정…**을 열면 단축키를 기록·변경하거나 끌 수 있습니다. 다른 앱과 충돌하는 단축키는 저장하지 않고 이전 단축키를 복원합니다.
- 설정에서 **로그인 시 Tab Finder 열기**를 선택할 수 있습니다. 이 기능은 앱을 `/Applications`에 설치한 뒤 사용하는 것이 좋습니다.

## 검색 범위와 제한

- Safari가 현재 창으로 공개하는 모든 열린 창과 탭을 검색합니다. 서로 다른 Safari 프로필의 열린 창도 같은 목록에 포함됩니다.
- 닫혀 있거나 비활성 상태인 Tab Group은 Safari의 열린 창 목록에 없으므로 검색하지 않습니다.
- 비공개 창을 별도로 제외하지 않습니다. 다만 실제 노출 여부는 사용 중인 Safari/macOS의 자동화 정책을 따릅니다.
- 탭을 선택하는 사이에 해당 탭이 이동하거나 닫히면 목록을 한 번 새로고침하고 안내합니다.
- 웹사이트 아이콘을 내려받지 않습니다. URL의 도메인 첫 글자와 로컬에서 계산한 색상을 사용합니다.

## 개인정보 보호

- 외부 네트워크 요청, 분석, 텔레메트리를 사용하지 않습니다.
- 탭 제목, URL, 검색어는 메모리에서만 처리하며 파일이나 로그에 기록하지 않습니다.
- 저장하는 값은 단축키, 단축키 사용 여부, 로그인 시 실행 여부뿐입니다.
- 필요한 시스템 권한은 Safari 자동화 권한뿐입니다. 손쉬운 사용, 전체 디스크 접근, 네트워크 권한은 사용하지 않습니다.

## 개발 명령

```bash
swift test
./scripts/build-app.sh
codesign -d --entitlements :- "outputs/Tab Finder.app" 2>&1
```
