//
//  TabManagerTests.swift
//  macSCPTests
//
//  Unit tests for TabManager
//

import XCTest
@testable import macSCP

@MainActor
final class TabManagerTests: XCTestCase {
    var sut: TabManager!
    var capturedSessions: [MockSFTPSession] = []

    override func setUp() async throws {
        try await super.setUp()
        capturedSessions = []
        sut = TabManager(viewModelFactory: makeViewModel)
    }

    override func tearDown() async throws {
        sut = nil
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

    private func makeConnection(name: String = "Test", host: String = "test.com") -> Connection {
        Connection(name: name, host: host, username: "user")
    }

    // MARK: - Open Tab Tests

    func testOpenTab_createsNewTab() {
        // Given
        let connection = makeConnection()

        // When
        sut.openTab(connection: connection, password: "pass")

        // Then
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.activeTabIndex, 0)
        XCTAssertEqual(sut.tabs.first?.connectionName, "Test")
        XCTAssertTrue(sut.hasTabs)
    }

    func testOpenTab_duplicateConnection_switchesToExisting() {
        // Given
        let connection = makeConnection()
        sut.openTab(connection: connection, password: "pass")

        // When
        sut.openTab(connection: connection, password: "pass")

        // Then
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.activeTabIndex, 0)
        XCTAssertEqual(capturedSessions.count, 1, "Should only create one session (no duplicate)")
    }

    func testOpenTab_multipleConnections() {
        // Given / When
        let conn1 = makeConnection(name: "Server 1", host: "host1.com")
        let conn2 = makeConnection(name: "Server 2", host: "host2.com")
        let conn3 = makeConnection(name: "Server 3", host: "host3.com")

        sut.openTab(connection: conn1, password: "pass1")
        sut.openTab(connection: conn2, password: "pass2")
        sut.openTab(connection: conn3, password: "pass3")

        // Then
        XCTAssertEqual(sut.tabs.count, 3)
        XCTAssertEqual(sut.activeTabIndex, 2)
        XCTAssertEqual(sut.tabs[0].connectionName, "Server 1")
        XCTAssertEqual(sut.tabs[1].connectionName, "Server 2")
        XCTAssertEqual(sut.tabs[2].connectionName, "Server 3")
    }

    // MARK: - Switch Tab Tests

    func testSwitchToTab_updatesActiveIndex() {
        // Given
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        let conn3 = makeConnection(name: "S3")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")

        // When
        sut.switchToTab(at: 1)

        // Then
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertEqual(sut.activeTab?.connectionName, "S2")
    }

    func testSwitchToTab_outOfBounds_noChange() {
        // Given
        let conn = makeConnection()
        sut.openTab(connection: conn, password: "p")
        sut.switchToTab(at: 0)

        // When
        sut.switchToTab(at: 5)

        // Then
        XCTAssertEqual(sut.activeTabIndex, 0)
    }

    func testSwitchToTab_byConnectionId() {
        // Given
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")

        // When
        let found = sut.switchToTab(for: conn1.id)

        // Then
        XCTAssertTrue(found)
        XCTAssertEqual(sut.activeTabIndex, 0)
        XCTAssertEqual(sut.activeTab?.connectionName, "S1")
    }

    func testSwitchToTab_byConnectionId_notFound() {
        // Given
        let conn = makeConnection()
        sut.openTab(connection: conn, password: "p")

        // When
        let found = sut.switchToTab(for: UUID())

        // Then
        XCTAssertFalse(found)
        XCTAssertEqual(sut.activeTabIndex, 0)
    }

    // MARK: - Close Tab Tests

    func testCloseTab_middleTab_adjustsIndex() async {
        // Given — 3 tabs, active = 2
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        let conn3 = makeConnection(name: "S3")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")
        sut.switchToTab(at: 2)

        // When — close tab at index 1 (middle)
        await sut.closeTab(at: 1)

        // Then — active shifts from 2 → 1 (C is now at index 1)
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertEqual(sut.activeTab?.connectionName, "S3")
    }

    func testCloseTab_activeTab_switchesToAdjacent() async {
        // Given — 3 tabs, active = 1
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        let conn3 = makeConnection(name: "S3")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")
        sut.switchToTab(at: 1)

        // When — close active tab (index 1)
        await sut.closeTab(at: 1)

        // Then — active stays at 1, which now points to S3 (next tab)
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertEqual(sut.activeTab?.connectionName, "S3")
    }

    func testCloseTab_activeLastTab_switchesToPrevious() async {
        // Given — 2 tabs, active = 1 (last)
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.switchToTab(at: 1)

        // When — close active tab (last)
        await sut.closeTab(at: 1)

        // Then — active moves to previous
        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.activeTabIndex, 0)
        XCTAssertEqual(sut.activeTab?.connectionName, "S1")
    }

    func testCloseTab_lastTab_clearsActive() async {
        // Given
        let conn = makeConnection()
        sut.openTab(connection: conn, password: "p")
        XCTAssertNotNil(sut.activeTabIndex)

        // When
        await sut.closeTab(at: 0)

        // Then
        XCTAssertEqual(sut.tabs.count, 0)
        XCTAssertNil(sut.activeTabIndex)
        XCTAssertNil(sut.activeTab)
        XCTAssertFalse(sut.hasTabs)
    }

    func testCloseTab_disconnectsSession() async {
        // Given
        let conn = makeConnection()
        sut.openTab(connection: conn, password: "p")
        let session = capturedSessions[0]

        // When
        await sut.closeTab(at: 0)

        // Then
        let wasCalled = await session.disconnectCalled
        XCTAssertTrue(wasCalled)
    }

    func testCloseAllTabs_disconnectsAll() async {
        // Given
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        let conn3 = makeConnection(name: "S3")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")

        // When
        await sut.closeAllTabs()

        // Then
        XCTAssertEqual(sut.tabs.count, 0)
        XCTAssertNil(sut.activeTabIndex)
        for session in capturedSessions {
            let wasCalled = await session.disconnectCalled
            XCTAssertTrue(wasCalled)
        }
    }
}
