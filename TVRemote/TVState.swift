import Foundation

/// R13–R16: snapshot of the TV parsed from `ADB.stateCommand` output; every field is nil when not found.
struct TVState: Equatable, Sendable {
    var awake: Bool?
    var app: String?
    var volume: Int?
    var title: String?
    var playing: Bool?

    private static let names = [
        "com.google.android.apps.tv.launcherx": "Главный экран", "com.google.android.youtube.tv": "YouTube",
        "com.netflix.ninja": "Netflix", "ru.kinopoisk.tv": "Кинопоиск", "com.spotify.tv.android": "Spotify",
    ]
    var appName: String? { app.map { Self.names[$0] ?? $0 } }

    init(awake: Bool? = nil, app: String? = nil, volume: Int? = nil, title: String? = nil, playing: Bool? = nil) {
        (self.awake, self.app, self.volume, self.title, self.playing) = (awake, app, volume, title, playing)
    }

    init(parsing out: String) {
        var state: Int?
        for line in out.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) {
            if line.hasPrefix("mWakefulness=") { awake = line.hasSuffix("Awake") ? true : (line.hasSuffix("Asleep") || line.hasSuffix("Dreaming")) ? false : nil }
            else if line.hasPrefix("mCurrentFocus="), let m = line.firstMatch(of: /\su0 ([^\s\/}]+)/) { app = String(m.1) }
            else if let m = line.firstMatch(of: /volume is (\d+) in range/) { volume = Int(m.1) }
            else if line.hasPrefix("package=") { state = nil }
            else if let m = line.firstMatch(of: /^state=PlaybackState \{state=(\d+)/) { state = Int(m.1) }
            else if line.hasPrefix("metadata:"), playing == nil, let s = state, s == 2 || s == 3 {
                playing = s == 3
                // shortcut: titles containing ", " get cut at the comma, upgrade if the TV's metadata format allows quoting.
                title = line.firstMatch(of: /description=(.*?)(?:, |$)/).map { String($0.1) }
            }
        }
    }
}
