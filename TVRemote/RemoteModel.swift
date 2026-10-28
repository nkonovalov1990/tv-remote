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
        case .failed(let m): status = "Ошибка: \(m)"
        }
    }

    // Each press awaits the previous one so rapid taps reach the TV in order.
    func press(_ key: Key) async {
        let prev = last
        let t = Task {
            await prev?.value
            do { try await adb.press(key, host: host) } catch { status = "Ошибка: \(error.localizedDescription)" }
        }
        last = t
        await t.value
    }
}
