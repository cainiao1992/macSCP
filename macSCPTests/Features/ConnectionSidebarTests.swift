//
//  ConnectionSidebarTests.swift
//  macSCPTests
//
//  Integration tests for sidebar-to-tab integration:
//  verifying that ConnectionListViewModel correctly opens tabs
//  via TabManager, with dedup and multi-connection support.
//

import XCTest
@testable import macSCP

// MARK: - Tests

@MainActor
final class ConnectionSidebarTests: XCTestCase {
    var sut: ConnectionListViewModel!
    var mockConnectionRepository: MockConnectionRepository!
    var mockFolderRepository: MockFolderRepository!
    var mockKeychainService: MockKeychainService!
    var mockWindowManager: WindowManager!
    var tabManager: TabManager!
    var capturedSessions: [MockSFTPSession] = []

    override func setUp() async throws {
        try await super.setUp()
        mockConnectionRepository = MockConnectionRepository()
        mockFolderRepository = MockFolderRepository()
        mockKeychainService = MockKeychainService()
        mockWindowManager = WindowManager.shared
        capturedSessions = []

        tabManager = TabManager(viewModelFactory: makeViewModel)

        sut = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: tabManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockConnectionRepository = nil
        mockFolderRepository = nil
        mockKeychainService = nil
        mockWindowManager = nil
        tabManager = nil
        capturedSessions = []
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeViewModel(connection: Connection, password: String) -> FileBrowserViewModel {
        let session = MockSFTPSession()
        capturedSessions.append(session)
        let repository = MockFileRepository()
        let clipboard = MockClipboardService()
        return FileBrowserViewModel(
            connection: connection,
            sftpSession: session,
            fileRepository: repository,
            clipboardService: clipboard,
            password: password
        )
    }

    private func makeConnection(
        name: String = "Test Server",
        host: String = "test.example.com",
        authMethod: AuthMethod = .password
    ) -> Connection {
        Connection(name: name, host: host, username: "user", authMethod: authMethod)
    }

    // MARK: - testConnectToServer_opensTab

    /// When calling connectWithPassword, the VM should open a tab via TabManager
    /// with the correct connection and password.
    func testConnectToServer_opensTab() {
        // Given
        let connection = makeConnection(name: "My Server", host: "myserver.com")
        let savedPassword = "s3cret"

        // Set connectionToConnect (normally done by connectToServer after auth gate)
        sut.connectionToConnect = connection

        // When
        sut.connectWithPassword(savedPassword)

        // Then — TabManager received the call
        XCTAssertEqual(tabManager.tabs.count, 1, "Should have opened exactly one tab")
        XCTAssertEqual(tabManager.tabs.first?.connectionName, "My Server")
        XCTAssertEqual(tabManager.tabs.first?.host, "myserver.com")

        // Password prompt should be dismissed
        XCTAssertFalse(sut.isShowingPasswordPrompt, "Password prompt should be dismissed after connect")
        XCTAssertNil(sut.connectionToConnect, "connectionToConnect should be cleared after connect")
    }

    // MARK: - testConnectToServer_duplicateConnection_switchesToExisting

    /// When connecting to a connection that already has an open tab,
    /// TabManager should deduplicate: switch to existing tab, not create a new one.
    func testConnectToServer_duplicateConnection_switchesToExisting() {
        // Given — open a tab for this connection via TabManager directly
        let connection = makeConnection(name: "Existing Server", host: "existing.com")
        tabManager.openTab(connection: connection, password: "old-pass")

        // Verify initial state
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.activeTabIndex, 0)

        // When — connect to the same connection again via VM
        sut.connectionToConnect = connection
        sut.connectWithPassword("new-pass")

        // Then — openTab was called but TabManager deduplicates
        XCTAssertEqual(tabManager.tabs.count, 1, "Should still have only 1 tab (no duplicate)")
        XCTAssertEqual(tabManager.activeTabIndex, 0, "Should still point to the existing tab")
    }

    // MARK: - testConnectToServer_multipleConnections

    /// Opening tabs for 3 different connections should result in 3 tabs,
    /// with the last one being active.
    func testConnectToServer_multipleConnections() {
        // Given
        let conn1 = makeConnection(name: "Server A", host: "a.example.com")
        let conn2 = makeConnection(name: "Server B", host: "b.example.com")
        let conn3 = makeConnection(name: "Server C", host: "c.example.com")

        // When — connect to all three sequentially via VM
        sut.connectionToConnect = conn1
        sut.connectWithPassword("pass1")

        sut.connectionToConnect = conn2
        sut.connectWithPassword("pass2")

        sut.connectionToConnect = conn3
        sut.connectWithPassword("pass3")

        // Then — 3 tabs exist, last is active
        XCTAssertEqual(tabManager.tabs.count, 3, "Should have opened 3 tabs")

        XCTAssertEqual(tabManager.tabs[0].connectionName, "Server A")
        XCTAssertEqual(tabManager.tabs[1].connectionName, "Server B")
        XCTAssertEqual(tabManager.tabs[2].connectionName, "Server C")

        XCTAssertEqual(tabManager.activeTabIndex, 2, "Last opened tab should be active")
        XCTAssertEqual(tabManager.activeTab?.connectionName, "Server C")
    }

    // MARK: - Cancel Connection Tests

    /// Cancelling the password prompt clears connectionToConnect and hides the prompt.
    func testCancelConnect_clearsState() {
        sut.connectionToConnect = makeConnection()
        sut.isShowingPasswordPrompt = true

        sut.cancelConnect()

        XCTAssertNil(sut.connectionToConnect)
        XCTAssertFalse(sut.isShowingPasswordPrompt)
        XCTAssertEqual(tabManager.tabs.count, 0, "No tab should be opened on cancel")
    }

    // MARK: - Private Key Auth Tests

    /// Private key auth connections should open a tab with an empty password
    /// (no password prompt needed).
    func testPrivateKeyAuth_opensTabWithEmptyPassword() {
        // Given — create a connection with private key auth
        let connection = makeConnection(name: "Key Server", host: "key.example.com", authMethod: .privateKey)

        // When
        sut.connectionToConnect = connection
        sut.connectWithPassword("")

        // Then
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.connectionName, "Key Server")
    }

    // MARK: - S3 Connection Tests

    /// S3 connections should open a tab with the correct connection type.
    func testS3Connection_opensTabWithCorrectType() {
        // Given
        var connection = makeConnection(name: "S3 Bucket", host: "s3.amazonaws.com")
        connection.connectionType = .s3
        connection.s3Bucket = "my-bucket"

        // When
        sut.connectionToConnect = connection
        sut.connectWithPassword("secretAccessKey")

        // Then
        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs.first?.connectionName, "S3 Bucket")
        XCTAssertEqual(tabManager.tabs.first?.connectionType, .s3)
    }

    // MARK: - Session Isolation Tests

    /// Each tab should have its own session (isolation between connections).
    func testConnectToServer_createsSeparateSessions() {
        // Given
        let conn1 = makeConnection(name: "S1", host: "h1.com")
        let conn2 = makeConnection(name: "S2", host: "h2.com")

        // When
        sut.connectionToConnect = conn1
        sut.connectWithPassword("p1")

        sut.connectionToConnect = conn2
        sut.connectWithPassword("p2")

        // Then — two separate sessions were created
        XCTAssertEqual(capturedSessions.count, 2, "Each connection should get its own session")
        XCTAssertEqual(tabManager.tabs.count, 2)
    }
}
