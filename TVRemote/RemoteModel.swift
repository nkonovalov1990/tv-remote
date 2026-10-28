import Foundation
import Observation

enum Tab: String { case media, nav }

@Observable @MainActor
final class RemoteModel {
    var host: String { didSet { defaults.set(host, forKey: "host") } }
    var tab: Tab { didSet { defaults.set(tab.rawValue, forKey: "tab") } }
    var status = "Не подключено"
    var isConnected = false
    @ObservationIgnored private let adb: ADB
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var last: Task<Void, Never>?

    init(adb: ADB = .live, defaults: UserDefaults = .standard) {
        self.adb = adb
        self.defaults = defaults
        host = defaults.string(forKey: "host") ?? ""
        tab = defaults.string(forKey: "tab").flatMap(Tab.init) ?? .media
    }

    func connectIfSaved() async {
        if ADB.isValidHost(host) { await connect() }
    }

    func connect() async {
        isConnected = false
        guard ADB.isValidHost(host) else { status = "Неверный IP"; return }
        switch await adb.connect(host) {
        case .connected: status = "Подключено"; isConnected = true
        case .unauthorized: status = "Разрешите подключение на ТВ и нажмите «Подключить» ещё раз"
        case .failed(let m): status = Self.error(m)
        }
    }

    // Each press awaits the previous one so rapid taps reach the TV in order.
    func press(_ key: Key) async {
        let prev = last
        let t = Task {
            await prev?.value
            do { try await adb.press(key, host: host) } catch { status = Self.error(error.localizedDescription) }
        }
        last = t
        await t.value
    }
}

extension RemoteModel {
    // R11: EHOSTUNREACH while the TV answers ping = macOS Local Network privacy blocking adb.
    static func error(_ m: String) -> String {
        m.contains("No route to host")
            ? "macOS блокирует локальную сеть: Настройки → Конфиденциальность и безопасность → Локальная сеть → включите TV Remote"
            : "Ошибка: \(m)"
    }
}
