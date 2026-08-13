//
//  ConnectionInitiatorTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionInitiator — proves independent testability (VM-SPLIT-03)
//  and the callback-based facade pattern (onSetConnectionToConnect / onShowPasswordPrompt).
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionInitiatorTests: XCTestCase {
    // MARK: - Dependencies
    var mockKeychainService: MockKeychainService!
    var mockWindowManager: MockWindowManager!
    var mockAppLockManager: MockAppLockManager!
    var tabManager: TabManager!

    // MARK: - Captured Callback State
    var capturedConnectionToConnect: Connection?
    var passwordPromptShown = false
    var capturedPendingTerminalWindowId: String?

    let testConnection = Connection(name: "Test Server", host: "test.example.com", username: "user")

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockKeychainService = MockKeychainService()
        mockKeychainService.reset()
        mockWindowManager = MockWindowManager()
        mockAppLockManager = MockAppLockManager()
        capturedConnectionToConnect = nil
        passwordPromptShown = false
        capturedPendingTerminalWindowId = nil
    }

    override func tearDown() async throws {
        tabManager = nil
        mockKeychainService = nil
        mockWindowManager = nil
        mockAppLockManager = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Builds a TabManager whose factory constructs a real (mock-backed) FileBrowserViewModel,
    /// so that `openTab` appends a tab without crashing.
    private func makeTabManager() -> TabManager {
        TabManager(viewModelFactory: { connection, password in
            FileBrowserViewModel(
                connection: connection,
                sftpSession: MockSFTPSession(),
                fileRepository: MockFileRepository(),
                clipboardService: MockClipboardService(),
                windowManager: MockWindowManager(),
                password: password
            )
        })
    }

    private func makeSut() -> ConnectionInitiator {
        ConnectionInitiator(
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: tabManager,
            appLockManager: mockAppLockManager,
            getConnectionToConnect: { [weak self] in self?.capturedConnectionToConnect },
            onSetConnectionToConnect: { [weak self] conn in self?.capturedConnectionToConnect = conn },
            onShowPasswordPrompt: { [weak self] show in if show { self?.passwordPromptShown = true } },
            onSetPendingTerminalWindowId: { [weak self] id in self?.capturedPendingTerminalWindowId = id }
        )
    }

    /// Polls until `condition` becomes true or `timeout` elapses. connectToServer spawns an
    /// async Task on the main actor; awaiting `Task.sleep` yields so that Task can run.
    private func waitForCondition(timeout: TimeInterval = 2.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - Independent Instantiation (VM-SPLIT-03)

    func testConnectionInitiator_CanBeInstantiatedWithMockDeps() {
        tabManager = makeTabManager()
        let sut = makeSut()
        XCTAssertNotNil(sut)
    }

    // MARK: - connectToServer: saved password + biometric allowed → openFileBrowser

    func testConnectToServer_WithSavedPasswordAndAuthAllowed_OpensFileBrowser() async {
        tabManager = makeTabManager()
        mockKeychainService.mockPasswords = [testConnection.id: "savedpass"]
        mockAppLockManager.authenticateForConnectionResult = true
        let sut = makeSut()

        sut.connectToServer(testConnection)

        await waitForCondition { !self.tabManager.tabs.isEmpty }

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.connectionId, testConnection.id)
        XCTAssertEqual(capturedConnectionToConnect?.id, testConnection.id)
        XCTAssertFalse(passwordPromptShown)
    }

    // MARK: - connectToServer: no saved password → shows password prompt

    func testConnectToServer_WithNoSavedPassword_ShowsPasswordPrompt() async {
        tabManager = makeTabManager()
        // No saved password; default authMethod is .password (not privateKey)
        mockAppLockManager.authenticateForConnectionResult = true
        let sut = makeSut()

        sut.connectToServer(testConnection)

        await waitForCondition { self.passwordPromptShown }

        XCTAssertTrue(passwordPromptShown)
        XCTAssertEqual(capturedConnectionToConnect?.id, testConnection.id)
        XCTAssertTrue(tabManager.tabs.isEmpty)
    }

    // MARK: - connectToServer: biometric denied → no browser, no prompt

    func testConnectToServer_WithAuthDenied_DoesNotOpenBrowserOrPrompt() async {
        tabManager = makeTabManager()
        mockKeychainService.mockPasswords = [testConnection.id: "savedpass"]
        mockAppLockManager.authenticateForConnectionResult = false
        let sut = makeSut()

        sut.connectToServer(testConnection)

        // Auth denial returns immediately from the Task's guard; settle briefly then assert.
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(tabManager.tabs.isEmpty)
        XCTAssertFalse(passwordPromptShown)
        XCTAssertNil(capturedConnectionToConnect)
    }
}
