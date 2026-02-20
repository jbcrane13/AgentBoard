import Foundation
import Network

/// Discovers OpenClaw gateways on the local network via Bonjour/mDNS.
@MainActor
final class GatewayDiscovery: ObservableObject {
    @Published var discoveredGateways: [DiscoveredGateway] = []
    @Published var isSearching = false

    private var browser: NWBrowser?
    private var resolveTimers: [String: Task<Void, Never>] = [:]

    struct DiscoveredGateway: Identifiable, Hashable {
        let id: String
        let name: String
        let host: String
        let port: UInt16

        var url: String { "http://\(host):\(port)" }
    }

    func startBrowsing() {
        stopBrowsing()
        discoveredGateways = []
        isSearching = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_openclaw._tcp", domain: nil)
        let params = NWParameters()
        params.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: params)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }

        browser.start(queue: .main)
        self.browser = browser

        // Auto-stop after 10 seconds
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            self?.isSearching = false
        }
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isSearching = false
        for (_, task) in resolveTimers {
            task.cancel()
        }
        resolveTimers.removeAll()
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, let type, let domain, _) = result.endpoint {
                resolveEndpoint(name: name, type: type, domain: domain)
            }
        }
    }

    private func resolveEndpoint(name: String, type: String, domain: String) {
        let key = "\(name).\(type).\(domain)"
        guard resolveTimers[key] == nil else { return }

        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let params = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: params)

        resolveTimers[key] = Task { @MainActor [weak self] in
            connection.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            hostStr = "\(addr)"
                        case .ipv6(let addr):
                            hostStr = "\(addr)"
                        case .name(let hostname, _):
                            hostStr = hostname
                        @unknown default:
                            hostStr = "\(host)"
                        }

                        Task { @MainActor [weak self] in
                            let gateway = DiscoveredGateway(
                                id: key,
                                name: name,
                                host: hostStr,
                                port: port.rawValue
                            )
                            if let self, !self.discoveredGateways.contains(where: { $0.id == key }) {
                                self.discoveredGateways.append(gateway)
                            }
                        }
                    }
                    connection.cancel()
                }
            }
            connection.start(queue: .main)

            // Timeout resolve after 5s
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            connection.cancel()
        }
    }
}
