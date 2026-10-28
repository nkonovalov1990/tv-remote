// Covers R1 (host persistence), R3 (connect -> status), R7 (error -> status), R9 (tab persistence), R10 (connectIfSaved, isConnected), R11 (Local Network hint).
import Testing
import Foundation
import Synchronization
@testable import TVRemote

@MainActor
private func make(_ f: Fake, _ d: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!) -> RemoteModel {
    RemoteModel(adb: f.adb, defaults: d)
}

@MainActor @Test("R1: host persists across model instances")
func hostPersists() {
    let d = UserDefaults(suiteName: UUID().uuidString)!
    #expect(make(Fake(), d).host == "")
    make(Fake(), d).host = "192.168.1.5"
    #expect(make(Fake(), d).host == "192.168.1.5")
}

@MainActor @Test("R3: initial status")
func initialStatus() { #expect(make(Fake()).status == "Не подключено") }

@MainActor @Test("R3: connect success => Подключено")
func modelConnectOK() async {
    let m = make(Fake(["connected to 1.1.1.1:5555", "device"]))
    m.host = "192.168.1.5"
    await m.connect()
    #expect(m.status == "Подключено")
}

@MainActor @Test("R3: connect unauthorized => prompt to allow on TV")
func modelUnauthorized() async {
    let m = make(Fake(["failed to authenticate to 192.168.1.5:5555"]))
    m.host = "192.168.1.5"
    await m.connect()
    #expect(m.status == "Разрешите подключение на ТВ и нажмите «Подключить» ещё раз")
}

@MainActor @Test("R3: invalid IP => Неверный IP")
func modelInvalid() async {
    let f = Fake()
    let m = make(f)
    m.host = "nope"
    await m.connect()
    #expect(m.status == "Неверный IP")
    #expect(f.recorded.isEmpty)
}

@MainActor @Test("R7: connect failure => Ошибка: output")
func modelFailed() async {
    let m = make(Fake(["failed to connect to '192.168.1.5:5555'"]))
    m.host = "192.168.1.5"
    await m.connect()
    #expect(m.status == "Ошибка: failed to connect to '192.168.1.5:5555'")
}

@MainActor @Test("R7: press error => Ошибка: message")
func modelPressError() async {
    let m = make(Fake(["error: closed"]))
    m.host = "192.168.1.5"
    await m.press(.home)
    #expect(m.status == "Ошибка: error: closed")
}

@MainActor @Test("R4: press success leaves status unchanged and sends key")
func pressOK() async {
    let f = Fake()
    let m = make(f)
    m.host = "192.168.1.5"
    await m.press(.home)
    #expect(m.status == "Не подключено")
    #expect(f.recorded == [["-s", "192.168.1.5:5555", "shell", "input", "keyevent", "3"]])
}

@MainActor @Test("R4: rapid presses reach adb in call order")
func pressesAreOrdered() async {
    let seen = Mutex<[String]>([])
    let n = Mutex(0)
    let adb = ADB { args in
        let i = n.withLock { $0 += 1; return $0 }
        if i == 1 { try await Task.sleep(for: .milliseconds(200)) } // first call is slowest
        seen.withLock { $0.append(args.last!) }
        return ""
    }
    let m = RemoteModel(adb: adb, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    m.host = "192.168.1.5"
    let a = Task { await m.press(.up) }
    let b = Task { await m.press(.down) }
    await a.value; await b.value
    #expect(seen.withLock { $0 } == ["19", "20"])
}

@MainActor @Test("R9: tab defaults to media and persists")
func tabPersists() {
    let d = UserDefaults(suiteName: UUID().uuidString)!
    #expect(make(Fake(), d).tab == .media)
    make(Fake(), d).tab = .nav
    #expect(make(Fake(), d).tab == .nav)
}

@MainActor @Test("R10: connectIfSaved with valid saved host connects")
func connectIfSavedValid() async {
    let f = Fake(["connected to 192.168.1.5:5555", "device"])
    let m = make(f)
    m.host = "192.168.1.5"
    await m.connectIfSaved()
    #expect(m.status == "Подключено")
    #expect(m.isConnected)
    #expect(f.recorded.count == 2)
}

@MainActor @Test("R10: connectIfSaved without valid host does nothing")
func connectIfSavedInvalid() async {
    for h in ["", "nope"] {
        let f = Fake()
        let m = make(f)
        m.host = h
        await m.connectIfSaved()
        #expect(m.status == "Не подключено")
        #expect(!m.isConnected)
        #expect(f.recorded.isEmpty)
    }
}

@MainActor @Test("R10: failed connect leaves isConnected false")
func notConnectedOnFailure() async {
    let m = make(Fake(["failed to connect to '192.168.1.5:5555'"]))
    m.host = "192.168.1.5"
    await m.connect()
    #expect(!m.isConnected)
}

private let localNetworkHint = "macOS блокирует локальную сеть: Настройки → Конфиденциальность и безопасность → Локальная сеть → включите TV Remote"

@MainActor @Test("R11: 'No route to host' on connect => Local Network hint")
func connectNoRouteHint() async {
    let m = make(Fake(["failed to connect to '192.168.1.5:5555': No route to host"]))
    m.host = "192.168.1.5"
    await m.connect()
    #expect(m.status == localNetworkHint)
}

@MainActor @Test("R11: 'No route to host' on press => Local Network hint")
func pressNoRouteHint() async {
    let m = make(Fake(["error: device '192.168.1.5:5555' not found; No route to host"]))
    m.host = "192.168.1.5"
    await m.press(.ok)
    #expect(m.status == localNetworkHint)
}
