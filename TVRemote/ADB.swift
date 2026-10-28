import Foundation
import Network

struct ADBError: LocalizedError {
    var errorDescription: String?
}

enum ConnectResult: Equatable, Sendable { case connected, unauthorized, failed(String) }

struct ADB: Sendable {
    /// Takes adb arguments (without the binary), returns combined stdout+stderr.
    var run: @Sendable ([String]) async throws -> String

    // R6: host goes into argv, so accept only literal IPs (rejects "-H", shell junk, hostnames).
    static func isValidHost(_ s: String) -> Bool {
        // IPv4Address("1.2.3") succeeds (inet_aton shorthand), so insist on 4 octets.
        (IPv4Address(s) != nil && s.split(separator: ".", omittingEmptySubsequences: false).count == 4) || IPv6Address(s) != nil
    }

    private func serial(_ host: String) -> String {
        host.contains(":") ? "[\(host)]:5555" : "\(host):5555"
    }

    func connect(_ host: String) async -> ConnectResult {
        guard Self.isValidHost(host) else { return .failed("invalid host") }
        do {
            // adb connect exits 0 even on failure, so parse the text.
            let out = try await run(["connect", serial(host)]).trimmingCharacters(in: .whitespacesAndNewlines)
            if out.contains("failed to authenticate") { return .unauthorized }
            guard out.contains("connected to"),
                  !["failed", "unable", "cannot"].contains(where: out.contains) else { return .failed(out) }
            // "connected" is also printed before the TV has accepted the RSA key.
            let state = try await run(["-s", serial(host), "get-state"]).trimmingCharacters(in: .whitespacesAndNewlines)
            if state == "device" { return .connected }
            return state.contains("unauthorized") ? .unauthorized : .failed(state)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func press(_ key: Key, host: String) async throws {
        guard Self.isValidHost(host) else { throw ADBError(errorDescription: "invalid host") }
        let out = try await run(["-s", serial(host), "shell", "input", "keyevent", "\(key.rawValue)"])
        if out.localizedCaseInsensitiveContains("error") { throw ADBError(errorDescription: out.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    static let live = ADB { args in
        let candidates = ["/opt/homebrew/bin/adb", "/usr/local/bin/adb",
                          NSString("~/Library/Android/sdk/platform-tools/adb").expandingTildeInPath]
        guard let bin = candidates.first(where: FileManager.default.isExecutableFile) else {
            throw ADBError(errorDescription: "adb not found — brew install android-platform-tools")
        }
        return try await withCheckedThrowingContinuation { cont in
            let p = Process()
            let pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = args
            p.standardOutput = pipe
            p.standardError = pipe
            // shortcut: output is read after exit; fine for tiny adb output, would deadlock past the 64KB pipe buffer.
            p.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(decoding: data, as: UTF8.self))
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}
