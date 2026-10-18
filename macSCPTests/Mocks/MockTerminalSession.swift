//
//  MockTerminalSession.swift
//  macSCPTests
//
//  Mock implementation of TerminalSessionProtocol for testing
//

import Foundation
@testable import macSCP

@MainActor
final class MockTerminalSession: TerminalSessionProtocol, @unchecked Sendable {
    // MARK: - State
    private(set) var isConnected = false
    private(set) var sessionEndedGracefully = false

    // MARK: - Recorded Calls
    var connectPasswordCalled = false
    var connectKeyCalled = false
    var sendCalled = false
    var resizeCalled = false
    var disconnectCalled = false

    // MARK: - Recorded Parameters
    var lastHost: String?
    var lastPort: Int?
    var lastUsername: String?
    var lastPassword: String?
    var lastPrivateKeyPath: String?
    var lastPassphrase: String?
    var lastTerminalSize: TerminalSize?
    var lastSentData: Data?
    var lastResizeColumns: Int?
    var lastResizeRows: Int?

    // MARK: - Response Stubs
    var mockError: Error?
    var mockOutputStream: AsyncStream<Data>?

    // MARK: - Sendable conformance: async accessors for non-MainActor contexts

    nonisolated var isConnectedAsync: Bool {
        get async { await self.isConnected }
    }

    nonisolated var sessionEndedGracefullyAsync: Bool {
        get async { await self.sessionEndedGracefully }
    }

    // MARK: - Protocol Implementation

    func connect(host: String, port: Int, username: String, password: String, terminalSize: TerminalSize) async throws {
        connectPasswordCalled = true
        lastHost = host
        lastPort = port
        lastUsername = username
        lastPassword = password
        lastTerminalSize = terminalSize
        if let error = mockError { throw error }
        isConnected = true
    }

    func connect(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String?, terminalSize: TerminalSize) async throws {
        connectKeyCalled = true
        lastHost = host
        lastPort = port
        lastUsername = username
        lastPrivateKeyPath = privateKeyPath
        lastPassphrase = passphrase
        lastTerminalSize = terminalSize
        if let error = mockError { throw error }
        isConnected = true
    }

    func send(_ data: Data) async throws {
        sendCalled = true
        lastSentData = data
    }

    var outputStream: AsyncStream<Data> {
        get async {
            if let stream = mockOutputStream { return stream }
            return AsyncStream { $0.finish() }
        }
    }

    func resize(columns: Int, rows: Int) async throws {
        resizeCalled = true
        lastResizeColumns = columns
        lastResizeRows = rows
    }

    func disconnect() async {
        disconnectCalled = true
        isConnected = false
    }

    // MARK: - Reset

    func reset() {
        isConnected = false
        sessionEndedGracefully = false
        connectPasswordCalled = false
        connectKeyCalled = false
        sendCalled = false
        resizeCalled = false
        disconnectCalled = false
        lastHost = nil
        lastPort = nil
        lastUsername = nil
        lastPassword = nil
        lastPrivateKeyPath = nil
        lastPassphrase = nil
        lastTerminalSize = nil
        lastSentData = nil
        lastResizeColumns = nil
        lastResizeRows = nil
        mockError = nil
        mockOutputStream = nil
    }
}
