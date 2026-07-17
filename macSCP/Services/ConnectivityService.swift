//
//  ConnectivityService.swift
//  macSCP
//
//  Lightweight connectivity check using TCP probe via NWConnection
//

import Foundation
import Network

enum ConnectionStatus: Equatable, Sendable {
    case checking
    case online
    case offline
}

/// Checks server connectivity by attempting a TCP connection with a timeout.
/// Uses Network.framework NWConnection for a non-blocking, lightweight probe.
actor ConnectivityService {
    static let shared = ConnectivityService()

    private let timeout: TimeInterval = 5.0

    private init() {}

    /// Check if a server is reachable by attempting a TCP connection.
    func checkConnectivity(host: String, port: Int) async -> ConnectionStatus {
        guard !host.isEmpty else { return .offline }

        // Use safe integer conversion to avoid runtime crash on out-of-range ports
        guard let rawPort = UInt16(exactly: port), rawPort > 0 else { return .offline }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: rawPort) ?? NWEndpoint.Port(rawValue: 22)!
        )
        let params = NWParameters.tcp
        params.prohibitedInterfaceTypes = [.loopback]
        let connection = NWConnection(to: endpoint, using: params)

        return await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func finish(_ status: ConnectionStatus) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: status)
            }

            connection.stateUpdateHandler = { (state: NWConnection.State) in
                switch state {
                case .ready:
                    finish(.online)
                case .failed:
                    finish(.offline)
                case .waiting:
                    finish(.offline)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // Timeout deadline
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                finish(.offline)
            }
        }
    }
}
