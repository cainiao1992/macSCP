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
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
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
    private(set) var isReconnecting: Bool = false
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

    /// Time when the current connection was established
    private(set) var connectedAt: Date?

    /// Formatted connection duration string (e.g. "5m 32s")
    private(set) var connectionDuration: String = ""

    // MARK: - Dependencies
    private let session: TerminalSessionProtocol
    private let connectionData: TerminalWindowData

    // MARK: - Output handling
    private var outputTask: Task<Void, Never>?
    private var pendingOutputBuffer: [Data] = []

    // MARK: - Connection timeout
    private var connectionTimeoutTask: Task<Void, Never>?
    private(set) var connectionAttemptDuration: String = ""
    private var connectionStartTime: Date?
    private var connectionAttemptTimerTask: Task<Void, Never>?

    // MARK: - Connection duration display
    private var connectionDurationTask: Task<Void, Never>?

    // MARK: - Auto-reconnect
    private var autoReconnectTask: Task<Void, Never>?
    private(set) var autoReconnectAttempt: Int = 0
    private(set) var autoReconnectCountdown: String = ""
    var isAutoReconnectEnabled: Bool = true
    static let maxAutoReconnectAttempts = 5
    private static let autoReconnectBaseDelay: TimeInterval = 2

    static let connectionTimeoutInterval: TimeInterval = 30

    var onOutput: ((Data) -> Void)? {
        didSet {
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

    // MARK: - Terminal font size
    var terminalFontSize: Int {
        didSet {
            UserDefaults.standard.set(terminalFontSize, forKey: "terminalFontSize")
        }
    }

    static let minFontSize = 8
    static let maxFontSize = 28
    static let defaultFontSize = 16

    // MARK: - Initialization

    init(
        connectionName: String,
        session: TerminalSessionProtocol,
        connectionData: TerminalWindowData
    ) {
        self.connectionName = connectionName
        self.session = session
        self.connectionData = connectionData
        self.terminalFontSize = UserDefaults.standard.integer(forKey: "terminalFontSize")
        if self.terminalFontSize == 0 {
            self.terminalFontSize = Self.defaultFontSize
        }
    }

    // MARK: - Connection

    func connect() async {
        switch state {
        case .disconnected, .error:
            break
        case .connecting, .connected:
            return
        }

        state = .connecting
        detectedHostKeyMismatch = false
        connectionStartTime = Date()
        startConnectionAttemptTimer()
        startConnectionTimeout()

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

            cancelConnectionTimeout()
            cancelConnectionAttemptTimer()
            isReconnecting = false
            isConnected = true
            connectedAt = Date()
            autoReconnectAttempt = 0
            state = .connected
            startConnectionDurationDisplayTimer()
            startOutputListener()

            logInfo("Terminal connected to \(connectionData.host)", category: .network)
        } catch {
            cancelConnectionTimeout()
            cancelConnectionAttemptTimer()
            isReconnecting = false
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
        cancelConnectionDurationDisplayTimer()
        cancelAutoReconnect()
        connectedAt = nil
        connectionDuration = ""

        await session.disconnect()
        isConnected = false
        state = .disconnected

        logInfo("Terminal disconnected", category: .network)
    }

    func reconnect() async {
        isReconnecting = true
        cancelAutoReconnect()
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

                if !detectedHostKeyMismatch {
                    if let text = String(data: data, encoding: .utf8),
                       (text.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || text.contains("Host key verification failed")) {
                        detectedHostKeyMismatch = true
                    }
                }

                await MainActor.run {
                    if let callback = self.onOutput {
                        callback(data)
                    } else {
                        self.pendingOutputBuffer.append(data)
                    }
                }
            }

            let graceful = await self.session.sessionEndedGracefully
            await MainActor.run {
                if self.isConnected {
                    self.cancelConnectionDurationDisplayTimer()
                    self.isConnected = false
                    if self.detectedHostKeyMismatch {
                        self.state = .error(.hostKeyMismatch(host: self.connectionData.host, port: self.connectionData.port))
                        self.isShowingHostKeyMismatchAlert = true
                    } else if graceful {
                        self.state = .disconnected
                    } else {
                        self.state = .error(.terminalConnectionLost)
                        if self.isAutoReconnectEnabled {
                            self.startAutoReconnect()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Terminal Size

    func resize(columns: Int, rows: Int) {
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
        cancelAutoReconnect()
        await disconnect()
    }

    // MARK: - Font Size

    func increaseFontSize() {
        guard terminalFontSize < Self.maxFontSize else { return }
        terminalFontSize += 1
    }

    func decreaseFontSize() {
        guard terminalFontSize > Self.minFontSize else { return }
        terminalFontSize -= 1
    }

    func resetFontSize() {
        terminalFontSize = Self.defaultFontSize
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

    // MARK: - Connection Timeout

    private func startConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.connectionTimeoutInterval))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.handleConnectionTimeout()
            }
        }
    }

    private func cancelConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
    }

    private func handleConnectionTimeout() {
        guard case .connecting = state else { return }
        logError("Terminal connection timed out", category: .network)
        cancelConnectionAttemptTimer()
        let timeoutError = AppError.connectionTimeout
        state = .error(timeoutError)
        self.error = timeoutError
        Task {
            await session.disconnect()
        }
    }

    func cancelConnection() async {
        cancelConnectionTimeout()
        cancelConnectionAttemptTimer()
        await disconnect()
    }

    // MARK: - Connection Attempt Timer

    private func startConnectionAttemptTimer() {
        connectionAttemptTimerTask?.cancel()
        connectionAttemptTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateConnectionAttemptDuration()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func cancelConnectionAttemptTimer() {
        connectionAttemptTimerTask?.cancel()
        connectionAttemptTimerTask = nil
        connectionAttemptDuration = ""
    }

    private func updateConnectionAttemptDuration() {
        guard let start = connectionStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        connectionAttemptDuration = "\(elapsed)s"
    }

    // MARK: - Connection Duration Display

    private func startConnectionDurationDisplayTimer() {
        connectionDurationTask?.cancel()
        connectionDurationTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateConnectionDuration()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func cancelConnectionDurationDisplayTimer() {
        connectionDurationTask?.cancel()
        connectionDurationTask = nil
        connectionDuration = ""
    }

    private func updateConnectionDuration() {
        guard let start = connectedAt else { return }
        let elapsed = Int(Date().timeIntervalSince(start))

        if elapsed < 60 {
            connectionDuration = "\(elapsed)s"
        } else if elapsed < 3600 {
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            connectionDuration = "\(minutes)m \(seconds)s"
        } else {
            let hours = elapsed / 3600
            let minutes = (elapsed % 3600) / 60
            connectionDuration = "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Auto-Reconnect

    private func startAutoReconnect() {
        cancelAutoReconnect()
        guard autoReconnectAttempt < Self.maxAutoReconnectAttempts else {
            logInfo("Auto-reconnect: max attempts reached", category: .network)
            return
        }

        autoReconnectAttempt += 1
        let delay = Self.autoReconnectBaseDelay * pow(2.0, Double(autoReconnectAttempt - 1))
        let clampedDelay = min(delay, 32.0)

        logInfo("Auto-reconnect: attempt \(autoReconnectAttempt) in \(Int(clampedDelay))s", category: .network)

        autoReconnectTask = Task { [weak self] in
            let totalWait = Int(clampedDelay)
            for remaining in stride(from: totalWait, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.autoReconnectCountdown = "\(remaining)s"
                }
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.autoReconnectCountdown = ""
                self?.isReconnecting = true
            }
            await self?.reconnect()
        }
    }

    private func cancelAutoReconnect() {
        autoReconnectTask?.cancel()
        autoReconnectTask = nil
        autoReconnectAttempt = 0
        autoReconnectCountdown = ""
    }
}
