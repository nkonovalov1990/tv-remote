# PLAN-0001: реализация SPEC-0001

Каждая задача идёт по TDD: красный тест → минимальный код → зелёный → запись в [журнал](../milestones.md).

Сборка: `xcodegen generate && xcodebuild test -project TVRemote.xcodeproj -scheme TVRemote -destination 'platform=macOS'`

## Структура
```
project.yml                  # xcodegen; .xcodeproj не коммитим
TVRemote/
  TVRemoteApp.swift          # @main, WindowGroup
  Key.swift                  # enum Key: Int (коды клавиш Android)            R4
  ADB.swift                  # struct ADB { run: ([String]) async throws -> String }  R3 R4 R6 R7
  RemoteModel.swift          # @Observable @MainActor final class             R1 R3 R7
  Discovery.swift            # NWBrowser _androidtvremote2._tcp → [TV(name, host)]  R2
  ContentView.swift          # UI + клавиатурные сокращения                   R2 R4 R5
  Info.plist                 # NSLocalNetworkUsageDescription, NSBonjourServices
TVRemoteTests/
  ADBTests.swift  RemoteModelTests.swift  DiscoveryTests.swift
```

## Контракты
- `ADB.isValidHost(_:) -> Bool` — только IPv4/IPv6 (`Network.IPv4Address/IPv6Address`).
- `ADB.connect(_ host:) async -> ConnectResult` (`.connected`, `.unauthorized`, `.failed(String)`); парсит вывод `adb connect`, потому что код выхода всегда 0.
- `ADB.press(_ key:, host:) async throws` → `adb -s <host>:5555 shell input keyevent <code>`.
- `ADB.live` — настоящий runner на `Process`; бинарник ищется в `/opt/homebrew/bin/adb`, `/usr/local/bin/adb`, `~/Library/Android/sdk/platform-tools/adb`.
- `RemoteModel(adb:, defaults:)` — `host` (сохраняется в UserDefaults под ключом `host`), `status: String`, `connect()`, `press(_:)`.
- `Discovery.hostString(_ host: NWEndpoint.Host) -> String?` — IP без суффикса интерфейса (`%en0`).

## Задачи
1. T1 Скелет: project.yml, Info.plist, пустое приложение собирается, тесты запускаются.
2. T2 `Key` + `ADB` по TDD с фейковым runner.
3. T3 `RemoteModel` по TDD с фейковым ADB и отдельным `UserDefaults(suiteName:)`.
4. T4 `Discovery` (тест на `hostString`) + `ContentView` + клавиатура.
5. T5 Проверка: все тесты зелёные, приложение запускается, ручная проверка на ТВ (делает пользователь).
