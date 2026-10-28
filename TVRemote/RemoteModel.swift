import Foundation
import Observation

@Observable @MainActor
final class RemoteModel {
    var host: String { didSet { defaults.set(host, forKey: "host") } }
    var status = "Не подключено"
    @ObservationIgnored private let adb: ADB
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var last: Task<Void, Never>?

    init(adb: ADB = .live, defaults: UserDefaults = .standard) {
        self.adb = adb
        self.defaults = defaults
        host = defaults.string(forKey: "host") ?? ""
    }

    func connect() async {
        guard ADB.isValidHost(host) else { status = "Неверный IP"; return }
        switch await adb.connect(host) {
        case .connected: status = "Подключено"
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
