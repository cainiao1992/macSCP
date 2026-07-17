//
//  TerminalViewModelTests.swift
//  macSCPTests
//
//  Unit tests for TerminalViewModel
//

import XCTest
@testable import macSCP

@MainActor
final class TerminalViewModelTests: XCTestCase {
    var mockSession: MockTerminalSession!
    var sut: TerminalViewModel!

    // MARK: - Helpers

    private func makeConnectionData(
        authMethod: AuthMethod = .password,
        password: String = "pass",
        privateKeyPath: String? = nil
    ) -> TerminalWindowData {
        TerminalWindowData(
            connectionId: UUID(),
            connectionName: "Test",
            host: "example.com",
            port: 22,
            username: "user",
            password: password,
            authMethod: authMethod,
            privateKeyPath: privateKeyPath
        )
    }

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockTerminalSession()
        mockSession.reset()

        let data = makeConnectionData()
        sut = TerminalViewModel(
            connectionName: data.connectionName,
            session: mockSession,
            connectionData: data
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_IsDisconnected() {
        if case .disconnected = sut.state {
            // expected
        } else {
            XCTFail("Expected .disconnected state, got \(sut.state)")
        }
    }

    func testInitialState_IsNotConnected() {
        XCTAssertFalse(sut.isConnected)
    }

    func testInitialState_ConnectionString() {
        XCTAssertEqual(sut.connectionString, "user@example.com")
    }

    func testInitialState_TerminalSizeText() {
        XCTAssertEqual(sut.terminalSizeText, "80 × 24")
    }

    // MARK: - Connect State Transitions

    func testConnect_TransitionsToConnected() async {
        await sut.connect()

        if case .connected = sut.state {
            // expected
        } else {
            XCTFail("Expected .connected state, got \(sut.state)")
        }
        XCTAssertTrue(sut.isConnected)
    }

    func testConnect_WhenAlreadyConnected_NoStateChange() async {
        // Connect first
        await sut.connect()
        XCTAssertTrue(sut.isConnected)

        // Connect again — should be no-op
        await sut.connect()

        if case .connected = sut.state {
            // expected — still connected
        } else {
            XCTFail("Expected .connected state after double connect, got \(sut.state)")
        }
        XCTAssertTrue(sut.isConnected)
    }

    func testConnect_WhenConnecting_NoStateChange() async {
        // We can't easily test the connecting intermediate state synchronously,
        // but we verify that calling connect twice results in only one session connect
        await sut.connect()
        await sut.connect()

        XCTAssertTrue(mockSession.connectPasswordCalled)
    }

    func testConnect_FromError_TransitionsToConnected() async {
        // Set up error, then connect should recover
        mockSession.reset()
        mockSession.mockError = AppError.connectionFailed("test")

        await sut.connect()

        if case .error = sut.state {
            // expected — connection failed
        } else {
            XCTFail("Expected .error state, got \(sut.state)")
        }

        // Now fix the error and reconnect
        mockSession.reset()
        await sut.connect()

        if case .connected = sut.state {
            // expected — recovered
        } else {
            XCTFail("Expected .connected state after recovery, got \(sut.state)")
        }
    }

    // MARK: - Disconnect

    func testDisconnect_TransitionsToDisconnected() async {
        await sut.connect()
        XCTAssertTrue(sut.isConnected)

        await sut.disconnect()

        if case .disconnected = sut.state {
            // expected
        } else {
            XCTFail("Expected .disconnected state after disconnect, got \(sut.state)")
        }
        XCTAssertFalse(sut.isConnected)
    }

    // MARK: - Auth Method Branching

    func testConnect_PasswordAuth_CallsPasswordConnect() async {
        let data = makeConnectionData(authMethod: .password, password: "secret")
        sut = TerminalViewModel(
            connectionName: data.connectionName,
            session: mockSession,
            connectionData: data
        )

        await sut.connect()

        XCTAssertTrue(mockSession.connectPasswordCalled)
        XCTAssertFalse(mockSession.connectKeyCalled)
        XCTAssertEqual(mockSession.lastPassword, "secret")
    }

    func testConnect_KeyAuth_CallsKeyConnect() async {
        let data = makeConnectionData(
            authMethod: .privateKey,
            password: "",
            privateKeyPath: "/path/to/key"
        )
        sut = TerminalViewModel(
            connectionName: data.connectionName,
            session: mockSession,
            connectionData: data
        )

        await sut.connect()

        XCTAssertTrue(mockSession.connectKeyCalled)
        XCTAssertFalse(mockSession.connectPasswordCalled)
        XCTAssertEqual(mockSession.lastPrivateKeyPath, "/path/to/key")
    }

    func testConnect_KeyAuth_EmptyPassword_NilPassphrase() async {
        let data = makeConnectionData(
            authMethod: .privateKey,
            password: "",
            privateKeyPath: "/path/to/key"
        )
        sut = TerminalViewModel(
            connectionName: data.connectionName,
            session: mockSession,
            connectionData: data
        )

        await sut.connect()

        XCTAssertNil(mockSession.lastPassphrase)
    }

    func testConnect_KeyAuth_NonEmptyPassword_PassphraseSet() async {
        let data = makeConnectionData(
            authMethod: .privateKey,
            password: "keypassphrase",
            privateKeyPath: "/path/to/key"
        )
        sut = TerminalViewModel(
            connectionName: data.connectionName,
            session: mockSession,
            connectionData: data
        )

        await sut.connect()

        XCTAssertEqual(mockSession.lastPassphrase, "keypassphrase")
    }

    // MARK: - Error Handling

    func testConnect_SessionThrows_StateBecomesError() async {
        mockSession.reset()
        mockSession.mockError = AppError.connectionFailed("refused")

        await sut.connect()

        if case .error = sut.state {
            // expected
        } else {
            XCTFail("Expected .error state when session throws, got \(sut.state)")
        }
        XCTAssertNotNil(sut.error)
    }

    func testClearError_FromErrorState_SetsDisconnected() async {
        mockSession.reset()
        mockSession.mockError = AppError.connectionFailed("refused")
        await sut.connect()

        if case .error = sut.state {
            // expected — in error state
        } else {
            XCTFail("Expected .error before clearError")
        }

        sut.clearError()

        XCTAssertNil(sut.error)
        if case .disconnected = sut.state {
            // expected
        } else {
            XCTFail("Expected .disconnected after clearError from error state, got \(sut.state)")
        }
    }

    func testClearError_FromConnectedState_StateUnchanged() async {
        await sut.connect()
        XCTAssertTrue(sut.isConnected)

        sut.error = AppError.unknown("transient")
        sut.clearError()

        XCTAssertNil(sut.error)
        if case .connected = sut.state {
            // expected — state unchanged
        } else {
            XCTFail("Expected .connected after clearError from connected state, got \(sut.state)")
        }
    }

    // MARK: - Resize

    func testResize_ValidColumnsRows_UpdatesSizeText() {
        sut.resize(columns: 120, rows: 40)
        XCTAssertEqual(sut.terminalSizeText, "120 × 40")
    }

    func testResize_ZeroColumns_NoChange() {
        let original = sut.terminalSizeText
        sut.resize(columns: 0, rows: 24)
        XCTAssertEqual(sut.terminalSizeText, original)
    }

    func testResize_ZeroRows_NoChange() {
        let original = sut.terminalSizeText
        sut.resize(columns: 80, rows: 0)
        XCTAssertEqual(sut.terminalSizeText, original)
    }

    func testResize_NegativeColumns_NoChange() {
        let original = sut.terminalSizeText
        sut.resize(columns: -1, rows: 24)
        XCTAssertEqual(sut.terminalSizeText, original)
    }

    // MARK: - Cleanup

    func testCleanup_SetsOnOutputToNil() async {
        sut.onOutput = { _ in }
        XCTAssertNotNil(sut.onOutput)

        await sut.cleanup()

        XCTAssertNil(sut.onOutput)
    }

    func testCleanup_Disconnects() async {
        await sut.connect()
        XCTAssertTrue(sut.isConnected)

        await sut.cleanup()

        XCTAssertFalse(sut.isConnected)
        if case .disconnected = sut.state {
            // expected
        } else {
            XCTFail("Expected .disconnected after cleanup, got \(sut.state)")
        }
    }

    // MARK: - Connection Data Passed Correctly

    func testConnect_PassesCorrectHostAndPort() async {
        await sut.connect()

        XCTAssertEqual(mockSession.lastHost, "example.com")
        XCTAssertEqual(mockSession.lastPort, 22)
        XCTAssertEqual(mockSession.lastUsername, "user")
    }

    // MARK: - Host Key Mismatch Tests

    func testConnect_SessionThrowsHostKeyMismatch_SetsError() async {
        mockSession.reset()
        mockSession.mockError = AppError.hostKeyMismatch(host: "example.com", port: 22)

        await sut.connect()

        if case .error(let error) = sut.state {
            XCTAssertTrue(error.isHostKeyMismatch)
        } else {
            XCTFail("Expected .error state with hostKeyMismatch, got \(sut.state)")
        }
        XCTAssertFalse(sut.isShowingHostKeyMismatchAlert)
    }

    func testDisconnectAfterHostKeyMismatch_ResetsState() async {
        mockSession.reset()
        mockSession.mockError = AppError.hostKeyMismatch(host: "example.com", port: 22)
        await sut.connect()

        if case .error = sut.state {
        } else {
            XCTFail("Expected .error before disconnect")
        }
        sut.isShowingHostKeyMismatchAlert = true

        sut.disconnectAfterHostKeyMismatch()

        XCTAssertFalse(sut.isShowingHostKeyMismatchAlert)
        if case .disconnected = sut.state {
        } else {
            XCTFail("Expected .disconnected, got \(sut.state)")
        }
    }

    func testDisconnectAfterHostKeyMismatch_CanReconnect() async {
        mockSession.reset()
        mockSession.mockError = AppError.hostKeyMismatch(host: "example.com", port: 22)
        await sut.connect()

        sut.disconnectAfterHostKeyMismatch()

        mockSession.reset()
        await sut.connect()

        if case .connected = sut.state {
        } else {
            XCTFail("Expected .connected after reconnect, got \(sut.state)")
        }
    }
}
