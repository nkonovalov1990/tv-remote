# PLAN-0002: реализация SPEC-0002

TDD там, где есть логика; вид проверяется скриншотом.

1. T6 Документы: SPEC-0002, ADR-0002, копия прототипа в `docs/design/`.
2. T7 `Key`: удалить неиспользуемые mute/rewind/fastForward/input/settings (+ их проверки в тестах).
3. T8 `RemoteModel` по TDD: `tab` (`.media`/`.nav`, сохраняется в UserDefaults под ключом `tab`), `connectIfSaved()` (подключается только при валидном сохранённом IP).
4. T9 `ContentView` по прототипу v2 + клавиша пробел; `TVRemoteApp` → `MenuBarExtra(.window)`, `Info.plist` → `LSUIElement`.
5. T10 Проверка: тесты, запуск, скриншот поповера, журнал вех.
