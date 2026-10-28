import Foundation
import Observation

enum Tab: String { case media, nav }

@Observable @MainActor
final class RemoteModel {
    var host: String {
        didSet {
            let t = host.trimmingCharacters(in: .whitespacesAndNewlines) // R25
            if t != host { host = t } else { defaults.set(host, forKey: "host") }
        }
    }
    var tab: Tab { didSet { defaults.set(tab.rawValue, forKey: "tab") } }
    var status = "Не подключено"
    var isConnected = false
    var tv: TVState?
    @ObservationIgnored private let adb: ADB
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var last: Task<Bool, Never>?
    @ObservationIgnored private var inFlight = 0
    var isBusy: Bool { inFlight > 0 } // R21: ContentView drops key auto-repeat while true

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

    // R17: a failed poll only blanks the extras; connection status is the user's, not the poll's.
    func refresh() async {
        guard isConnected else { return }
        tv = try? await adb.state(host: host)
    }

    // Each press awaits the previous one so rapid taps reach the TV in order.
    func press(_ key: Key) async {
        let prev = last
        inFlight += 1
        let t = Task {
            defer { inFlight -= 1 }
            _ = await prev?.value
            do { try await adb.press(key, host: host); return true } catch { status = Self.error(error.localizedDescription); isConnected = false; return false }
        }
        last = t
        // Refresh outside the chain so a ~0.4 s poll never delays the next keyevent.
        if await t.value { await refresh() }
    }
}

extension RemoteModel {
    nonisolated static let localNetworkHint = "macOS блокирует локальную сеть: Настройки → Конфиденциальность и безопасность → Локальная сеть → включите TV Remote"
    // R19: deep link to System Settings › Privacy & Security › Local Network.
    nonisolated static let localNetworkSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!

    // R11: EHOSTUNREACH while the TV answers ping = macOS Local Network privacy blocking adb.
    static func error(_ m: String) -> String {
        m.contains("No route to host") ? localNetworkHint : "Ошибка: \(m)"
    }
}
