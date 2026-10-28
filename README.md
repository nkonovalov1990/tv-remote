# TV Remote

Нативный macOS-пульт (SwiftUI) для TCL / Android TV по ADB через Wi‑Fi.
Спецификация: [SPEC-0001](docs/specs/0001-tv-remote/spec.md) · Решение по транспорту: [ADR-0001](docs/adr/0001-adb-transport.md) · План: [PLAN-0001](docs/plans/0001-tv-remote-plan.md) · Журнал: [milestones](docs/milestones.md)

## Запуск
```bash
brew install android-platform-tools xcodegen
xcodegen generate
xcodebuild test -project TVRemote.xcodeproj -scheme TVRemote -destination 'platform=macOS,arch=arm64'
open TVRemote.xcodeproj   # ⌘R
```
На ТВ один раз: режим разработчика → «Отладка по сети»; при первом подключении нажать «Разрешить».

## Процесс
SDD + TDD: каждое изменение начинается с правки спецификации (R‑id), затем красный тест, код, запись в журнал вех.
