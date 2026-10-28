// Covers R13 (power), R14 (app name), R15 (volume), R16 (title + play state) parsing.
import Testing
import Foundation
@testable import TVRemote

private func fixture(_ name: String) throws -> String {
    try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)"), encoding: .utf8)
}

@Test("R13-R16: real home screen output (bluetooth session in state 7 is ignored)")
func parseHome() throws {
    let s = TVState(parsing: try fixture("state-home.txt"))
    #expect(s == TVState(awake: true, app: "com.google.android.apps.tv.launcherx", volume: 22, title: nil, playing: nil))
    #expect(s.appName == "Главный экран")
}

@Test("R13-R16: playing session wins over the later bluetooth one")
func parsePlaying() throws {
    let s = TVState(parsing: try fixture("state-playing-synthetic.txt"))
    #expect(s == TVState(awake: true, app: "com.google.android.youtube.tv", volume: 35, title: "Lo-fi beats to relax", playing: true))
    #expect(s.appName == "YouTube")
}

@Test("R13-R16: asleep, no focus window")
func parseAsleep() throws {
    let s = TVState(parsing: try fixture("state-asleep-synthetic.txt"))
    #expect(s == TVState(awake: false, app: nil, volume: 22, title: nil, playing: nil))
}

@Test("R13: Dreaming counts as not awake")
func dreaming() { #expect(TVState(parsing: "  mWakefulness=Dreaming").awake == false) }

@Test("R16: first paused session gives play_fill state")
func paused() {
    let s = TVState(parsing: "package=x\nstate=PlaybackState {state=2, position=0}\nmetadata: size=1, description=Song, a, b")
    #expect(s.playing == false)
    #expect(s.title == "Song")
}

@Test("R14: unknown package falls back to its name")
func unknownApp() { #expect(TVState(parsing: "mCurrentFocus=Window{1 u0 org.foo.bar/org.foo.bar.Main}").appName == "org.foo.bar") }

@Test("R13-R16: garbage and empty input give all nil", arguments: ["", "garbage\n\nxyz"])
func garbage(_ s: String) { #expect(TVState(parsing: s) == TVState()) }
