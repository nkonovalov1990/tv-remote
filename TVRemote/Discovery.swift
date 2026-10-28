import Foundation
import Network
import Observation

struct TV: Identifiable, Hashable {
    let name: String
    let host: String
    var id: String { name }
}

@Observable @MainActor
final class Discovery {
    var tvs: [TV] = []
    @ObservationIgnored private var browser: NWBrowser?

    nonisolated static func hostString(_ h: NWEndpoint.Host) -> String? {
        switch h {
        case .ipv4(let a): "\(a)".split(separator: "%").first.map(String.init)
        case .ipv6(let a): "\(a)".split(separator: "%").first.map(String.init)
        default: nil
        }
    }

    func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: "_androidtvremote2._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated { // queue is .main
                for r in results {
                    guard case .service(let name, _, _, _) = r.endpoint else { continue }
                    self?.resolve(name, r.endpoint)
                }
            }
        }
        b.start(queue: .main)
        browser = b
    }

    func stop() { browser?.cancel(); browser = nil }

    // Connecting is the simplest way to turn a Bonjour service into an IP.
    private func resolve(_ name: String, _ endpoint: NWEndpoint) {
        guard !tvs.contains(where: { $0.name == name }) else { return }
        let params = NWParameters.tcp
        (params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)?.version = .v4
        let c = NWConnection(to: endpoint, using: params)
        c.stateUpdateHandler = { [weak self] state in
            guard case .ready = state else { return }
            let host: String? = if case .hostPort(let h, _) = c.currentPath?.remoteEndpoint { Self.hostString(h) } else { nil }
            c.cancel()
            guard let host else { return }
            MainActor.assumeIsolated {
                guard let self, !self.tvs.contains(where: { $0.name == name }) else { return }
                self.tvs.append(TV(name: name, host: host))
            }
        }
        c.start(queue: .main)
    }
}
