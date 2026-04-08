//
//  TerminalViewModel.swift
//  macSCP
//
//  ViewModel for the terminal feature
//

import Foundation
import SwiftUI

/// State of the terminal connection
enum TerminalState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(AppError)

    static func == (lhs: TerminalState, rhs: TerminalState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

@MainActor
@Observable
final class TerminalViewModel {
    // MARK: - Published State
    private(set) var state: TerminalState = .disconnected
    private(set) var isConnected: Bool = false
    var error: AppError?
    var isShowingHostKeyMismatchAlert = false
    private var detectedHostKeyMismatch = false

    let connectionName: String

    /// Connection string displayed in the subtitle (e.g. "user@host")
    var connectionString: String {
        "\(connectionData.username)@\(connectionData.host)"
    }

    /// Current terminal dimensions as a display string (e.g. "80 x 24")
    private(set) var terminalSizeText: String = TerminalSize.default.displayString

    // MARK: - Dependencies
    private let session: TerminalSessionProtocol
    private let connectionData: TerminalWindowData

    // MARK: - Output handling
    private var outputTask: Task<Void, Never>?
    private var pendingOutputBuffer: [Data] = []

    var onOutput: ((Data) -> Void)? {
        didSet {
            // When callback is set, flush any buffered data
            if let callback = onOutput {
                for data in pendingOutputBuffer {
                    callback(data)
                }
                pendingOutputBuffer.removeAll()
            }
        }
    }

    // MARK: - Terminal size
    private var currentSize: TerminalSize = .default

    // MARK: - Initialization

    init(
        connectionName: String,
        session: TerminalSessionProtocol,
        connectionData: TerminalWindowData
    ) {
        self.connectionName = connectionName
        self.session = session
        self.connectionData = connectionData
    }

    // MARK: - Connection

    func connect() async {
        // Only connect if disconnected or in error state
        switch state {
        case .disconnected, .error:
            break
        case .connecting, .connected:
            return
        }

        state = .connecting
        detectedHostKeyMismatch = false

        do {
            if connectionData.authMethod == .password {
                try await session.connect(
                    host: connectionData.host,
                    port: connectionData.port,
                    username: connectionData.username,
                    password: connectionData.password,
                    terminalSize: currentSize
                )
            } else if let keyPath = connectionData.privateKeyPath {
                try await session.connect(
                    host: connectionData.host,
                    port: connectionData.port,
                    username: connectionData.username,
                    privateKeyPath: keyPath,
                    passphrase: connectionData.password.isEmpty ? nil : connectionData.password,
                    terminalSize: currentSize
                )
            }

            isConnected = true
            state = .connected

            // Start listening for output
            startOutputListener()

            logInfo("Terminal connected to \(connectionData.host)", category: .network)
        } catch {
            logError("Terminal connection failed: \(error)", category: .network)
            let appError = AppError.from(error)
            state = .error(appError)
            self.error = appError
        }
    }

    func disconnect() async {
        outputTask?.cancel()
        outputTask = nil
        pendingOutputBuffer.removeAll()

        await session.disconnect()
        isConnected = false
        state = .disconnected

        logInfo("Terminal disconnected", category: .network)
    }

    func reconnect() async {
        await disconnect()
        await connect()
    }

    // MARK: - Input/Output

    func sendInput(_ data: Data) {
        guard isConnected else { return }

        Task {
            do {
                try await session.send(data)
            } catch {
                logError("Failed to send terminal input: \(error)", category: .network)
                self.error = AppError.from(error)
            }
        }
    }

    func sendInput(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        sendInput(data)
    }

    private func startOutputListener() {
        outputTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await session.outputStream

            for await data in stream {
                guard !Task.isCancelled else { break }

                // Check for host key mismatch in terminal output
                if !detectedHostKeyMismatch {
                    if let text = String(data: data, encoding: .utf8),
                       (text.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || text.contains("Host key verification failed")) {
                        detectedHostKeyMismatch = true
                    }
                }

                await MainActor.run {
                    // Buffer data if callback not yet set, otherwise deliver immediately
                    if let callback = self.onOutput {
                        callback(data)
                    } else {
                        self.pendingOutputBuffer.append(data)
                    }
                }
            }

            // Stream ended - check if session ended gracefully or unexpectedly
            let graceful = await self.session.sessionEndedGracefully
            await MainActor.run {
                if self.isConnected {
                    self.isConnected = false
                    if self.detectedHostKeyMismatch {
                        self.state = .error(.hostKeyMismatch(host: self.connectionData.host, port: self.connectionData.port))
                        self.isShowingHostKeyMismatchAlert = true
                    } else if graceful {
                        self.state = .disconnected
                    } else {
                        self.state = .error(.terminalConnectionLost)
                    }
                }
            }
        }
    }

    // MARK: - Terminal Size

    func resize(columns: Int, rows: Int) {
        // Validate size - must be positive
        guard columns > 0 && rows > 0 else { return }

        currentSize = TerminalSize(columns: columns, rows: rows)
        terminalSizeText = currentSize.displayString

        guard isConnected else { return }

        Task {
            do {
                try await session.resize(columns: columns, rows: rows)
            } catch {
                logError("Failed to resize terminal: \(error)", category: .network)
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() async {
        onOutput = nil
        await disconnect()
    }

    // MARK: - Host Key Mismatch

    func disconnectAfterHostKeyMismatch() {
        isShowingHostKeyMismatchAlert = false
        detectedHostKeyMismatch = false
        state = .disconnected
    }

    func replaceHostKeyAndReconnect() async {
        isShowingHostKeyMismatchAlert = false
        detectedHostKeyMismatch = false

        do {
            try HostKeyService.removeHostKey(host: connectionData.host, port: connectionData.port)
            logInfo("Host key replaced, reconnecting terminal", category: .network)
        } catch {
            logError("Failed to remove host key: \(error)", category: .network)
        }

        await reconnect()
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
        if case .error = state {
            state = .disconnected
        }
    }
}
