// Covers R3 (connect + auth check), R4/R4p (key codes / press), R6 (host validation), R7 (error surfacing), R13-R16 (state call).
import Testing
import Foundation
import Synchronization
@testable import TVRemote

/// Records args and returns canned outputs in order (last one repeats).
final class Fake: Sendable {
    let calls = Mutex<[[String]]>([])
    let outputs: [String]
    let error: (any Error)?
    init(_ outputs: [String] = [""], error: (any Error)? = nil) { self.outputs = outputs; self.error = error }
    var adb: ADB {
        ADB { args in
            let n = self.calls.withLock { $0.append(args); return $0.count }
            if let e = self.error { throw e }
            return self.outputs[min(n, self.outputs.count) - 1]
        }
    }
    var recorded: [[String]] { calls.withLock { $0 } }
}

struct Boom: LocalizedError { var errorDescription: String? { "boom" } }

@Test("R4p: key codes match Android KEYCODE values; removed keys are gone")
func keyCodes() {
    #expect(Key.power.rawValue == 26)
    #expect(Key.ok.rawValue == 23)
    #expect(Key.playPause.rawValue == 85)
    #expect(Key.allCases.count == 11)
}

@Test("R6: valid hosts accepted", arguments: ["192.168.1.5", "10.0.0.1", "fe80::1", "::1"])
func validHosts(h: String) { #expect(ADB.isValidHost(h)) }

@Test("R6: invalid hosts rejected", arguments: ["-H", "1.2.3", "foo;rm", "", "1.2.3.4:5555", "tv.local"])
func invalidHosts(h: String) { #expect(!ADB.isValidHost(h)) }

@Test("R6: connect with invalid host fails without calling adb")
func connectInvalidHost() async {
    let f = Fake()
    let r = await f.adb.connect("-H")
    #expect(r == .failed("invalid host"))
    #expect(f.recorded.isEmpty)
}

@Test("R3: connected + get-state device => .connected")
func connectOK() async {
    let f = Fake(["connected to 192.168.1.5:5555\n", "device\n"])
    #expect(await f.adb.connect("192.168.1.5") == .connected)
    #expect(f.recorded == [["connect", "192.168.1.5:5555"], ["-s", "192.168.1.5:5555", "get-state"]])
}

@Test("R3: already connected counts as connected")
func connectAlready() async {
    let f = Fake(["already connected to 192.168.1.5:5555", "device"])
    #expect(await f.adb.connect("192.168.1.5") == .connected)
}

@Test("R3: get-state unauthorized => .unauthorized")
func connectUnauthorizedState() async {
    let f = Fake(["connected to 192.168.1.5:5555", "error: device unauthorized.\n"])
    #expect(await f.adb.connect("192.168.1.5") == .unauthorized)
}

@Test("R3: failed to authenticate => .unauthorized")
func connectAuthFail() async {
    let f = Fake(["failed to authenticate to 192.168.1.5:5555"])
    #expect(await f.adb.connect("192.168.1.5") == .unauthorized)
}

@Test("R7: connection refused => .failed with trimmed output")
func connectRefused() async {
    let f = Fake(["failed to connect to '192.168.1.5:5555': Connection refused\n"])
    #expect(await f.adb.connect("192.168.1.5") == .failed("failed to connect to '192.168.1.5:5555': Connection refused"))
    #expect(f.recorded.count == 1)
}

@Test("R7: unexpected get-state => .failed")
func connectOddState() async {
    let f = Fake(["connected to 192.168.1.5:5555", "offline\n"])
    #expect(await f.adb.connect("192.168.1.5") == .failed("offline"))
}

@Test("R7: thrown error => .failed(localizedDescription)")
func connectThrows() async {
    #expect(await Fake(error: Boom()).adb.connect("192.168.1.5") == .failed("boom"))
}

@Test("R6: IPv6 serial is bracketed")
func ipv6Serial() async throws {
    let f = Fake()
    try await f.adb.press(.home, host: "fe80::1")
    #expect(f.recorded == [["-s", "[fe80::1]:5555", "shell", "input", "keyevent", "3"]])
}

@Test("R4: press sends keyevent with code")
func pressSends() async throws {
    let f = Fake()
    try await f.adb.press(.volumeUp, host: "192.168.1.5")
    #expect(f.recorded == [["-s", "192.168.1.5:5555", "shell", "input", "keyevent", "24"]])
}

@Test("R6: press with invalid host throws and does not call adb")
func pressInvalid() async {
    let f = Fake()
    await #expect(throws: (any Error).self) { try await f.adb.press(.home, host: "-H") }
    #expect(f.recorded.isEmpty)
}

@Test("R7: press output containing error throws with the output")
func pressError() async {
    let f = Fake(["error: device '192.168.1.5:5555' not found"])
    await #expect(throws: (any Error).self) { try await f.adb.press(.home, host: "192.168.1.5") }
    do { try await f.adb.press(.home, host: "192.168.1.5") } catch {
        #expect(error.localizedDescription.contains("not found"))
    }
}

private let hasAdb = ["/opt/homebrew/bin/adb", "/usr/local/bin/adb",
    NSString("~/Library/Android/sdk/platform-tools/adb").expandingTildeInPath]
    .contains { FileManager.default.isExecutableFile(atPath: $0) }

@Test("R3: live runner executes adb version", .enabled(if: hasAdb))
func liveVersion() async throws {
    #expect(try await ADB.live.run(["version"]).contains("Android Debug Bridge"))
}

@Test("R13-R16: state runs one shell call and parses the output")
func stateCall() async throws {
    let f = Fake(["  mWakefulness=Awake\n[V] volume is 7 in range [0..100]"])
    let s = try await f.adb.state(host: "192.168.1.5")
    #expect(f.recorded == [["-s", "192.168.1.5:5555", "shell", ADB.stateCommand]])
    #expect(s.awake == true && s.volume == 7)
}

@Test("R6: state with invalid host throws without calling adb")
func stateInvalidHost() async {
    let f = Fake()
    await #expect(throws: ADBError.self) { try await f.adb.state(host: "-H") }
    #expect(f.recorded.isEmpty)
}
