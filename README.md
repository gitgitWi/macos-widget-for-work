# WorkWidget - macOS Sidebar Work Widget

Teams, Calendar, Notion, GitHub 알림을 한곳에서 모아보는 macOS 사이드바 위젯.

## Features

- **통합 알림**: Teams, GitHub, Notion, macOS Calendar, Google Calendar
- **즐겨찾기**: 중요한 알림 3개를 상단에 고정
- **최근 알림**: 최신 5-7개 알림을 시간순 표시
- **사이드바 패널**: 포커스를 뺏지 않는 always-on-top 패널, 모든 Spaces에 표시
- **메뉴바 앱**: Dock 아이콘 없이 메뉴바에서 토글 (좌클릭: 패널 토글, 우클릭: 메뉴)
- **자동 폴링**: 설정 가능한 주기(30초~5분)로 자동 새로고침
- **서비스별 설정**: OAuth 인증, 서비스 노출 토글, 폴링 주기 설정
- **에러 처리**: 서비스별 에러 배너, 캘린더 권한 거부 시 시스템 설정 안내

## Tech Stack

- Swift 6.0 + SwiftUI + AppKit
- macOS 14+ (Sonoma)
- Swift Package Manager (Xcode 불필요)
- 외부 의존성: [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) (1개)

## Build & Run

```bash
# 디버그 빌드 및 직접 실행
swift build
.build/debug/WorkWidget

# .app 번들 생성 (release) - OAuth 콜백 URL scheme 필요 시
bash Scripts/build-app.sh
open WorkWidget.app
```

## OAuth 서비스 연동

각 서비스에 앱을 등록하고 환경변수로 Client ID/Secret을 제공해야 합니다.

| 서비스 | 등록 위치 | 환경변수 |
|--------|----------|----------|
| GitHub | GitHub Settings > Developer > OAuth Apps | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` |
| Teams | Azure Portal > App registrations | `MICROSOFT_CLIENT_ID` |
| Notion | notion.so/my-integrations | `NOTION_CLIENT_ID`, `NOTION_CLIENT_SECRET` |
| Google Calendar | Google Cloud Console > APIs & Credentials | `GOOGLE_CLIENT_ID` |
| macOS Calendar | 등록 불필요 (EventKit, 시스템 권한) | - |

콜백 URL: `workwidget://oauth/callback`

```bash
# 환경변수와 함께 실행
GITHUB_CLIENT_ID=xxx GITHUB_CLIENT_SECRET=yyy open WorkWidget.app
```

## Project Structure

```
Sources/
├── Main.swift                  # AppDelegate, 메뉴바 아이콘, 우클릭 메뉴
├── App/
│   ├── SidebarPanel.swift      # NSPanel (non-activating, floating)
│   └── PanelController.swift   # 패널 생성/관리
├── Models/                     # WorkNotification, ServiceType, OAuthTokens, ServiceConfig
├── ViewModels/
│   ├── NotificationStore.swift # 알림 상태관리, 폴링 타이머
│   └── SettingsStore.swift     # 설정 저장 (UserDefaults)
├── Services/
│   ├── NotificationService.swift      # 프로토콜 정의
│   ├── GitHubService.swift            # GitHub REST API
│   ├── TeamsService.swift             # Microsoft Graph API
│   ├── NotionService.swift            # Notion API
│   ├── EventKitCalendarService.swift  # macOS 기본 캘린더
│   └── GoogleCalendarService.swift    # Google Calendar API v3
├── Auth/
│   ├── OAuthManager.swift      # ASWebAuthenticationSession + PKCE
│   ├── OAuthConfig.swift       # 서비스별 OAuth 설정
│   └── KeychainManager.swift   # 토큰 저장/조회
├── Networking/
│   ├── HTTPClient.swift        # URLSession actor 래퍼
│   └── APIModels/              # 서비스별 API 응답 모델
└── Views/
    ├── PanelContentView.swift  # 루트 SwiftUI 뷰
    ├── PinnedSection.swift     # 상단 즐겨찾기 영역
    ├── RecentSection.swift     # 하단 최근 알림 (스크롤)
    ├── NotificationRow.swift   # 개별 알림 행 (호버 효과)
    ├── BottomBar.swift         # 새로고침 + 설정 버튼
    └── SettingsView.swift      # 설정 시트 (인증/토글/폴링)
```

## Implementation Status

- [x] Phase 1: 프로젝트 스캐폴딩 + 사이드바 셸 + Mock UI
- [x] Phase 2: OAuth 인증 + Keychain + HTTPClient
- [x] Phase 3: 서비스 통합 (GitHub/Teams/Notion/EventKit/Google Calendar)
- [x] Phase 4: UI 완성 (폴링, 애니메이션, 에러 처리, 호버 효과)
