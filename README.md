# WorkWidget - macOS Sidebar Work Widget

Teams, Calendar, Notion, GitHub 알림을 한곳에서 모아보는 macOS 사이드바 위젯.

## Features

- **통합 알림**: Teams, GitHub, Notion, macOS Calendar, Google Calendar
- **즐겨찾기**: 중요한 알림 3개를 상단에 고정
- **최근 알림**: 최신 5-7개 알림을 시간순 표시
- **사이드바 패널**: 포커스를 뺏지 않는 always-on-top 패널, 모든 Spaces에 표시
- **메뉴바 앱**: Dock 아이콘 없이 메뉴바에서 토글
- **서비스별 설정**: OAuth 인증 및 서비스 노출 토글

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

# .app 번들 생성 (release)
bash Scripts/build-app.sh
open WorkWidget.app
```

## Project Structure

```
Sources/
├── Main.swift                  # AppDelegate, 메뉴바 아이콘
├── App/
│   ├── SidebarPanel.swift      # NSPanel (non-activating, floating)
│   └── PanelController.swift   # 패널 생성/관리
├── Models/                     # WorkNotification, ServiceType, etc.
├── ViewModels/                 # NotificationStore, SettingsStore
├── Services/                   # API 클라이언트 (TODO)
├── Auth/                       # OAuth, Keychain (TODO)
├── Networking/                 # HTTPClient, API 모델 (TODO)
└── Views/                      # SwiftUI 뷰 컴포넌트
```

## Implementation Status

- [x] Phase 1: 프로젝트 스캐폴딩 + 사이드바 셸 + Mock UI
- [ ] Phase 2: OAuth 인증 + 설정 저장
- [ ] Phase 3: 서비스 통합 (GitHub/Teams/Notion/Calendar)
- [ ] Phase 4: UI 완성 (폴링, 애니메이션, 에러 처리)
