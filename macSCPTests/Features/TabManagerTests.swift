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

    // MARK: - State Independence Tests

    func testTabStateIndependence_switchingTabs_preservesState() async {
        // Given — two tabs, each with independent VMs
        let conn1 = makeConnection(name: "Server1", host: "host1.com")
        let conn2 = makeConnection(name: "Server2", host: "host2.com")
        sut.openTab(connection: conn1, password: "pass1")
        sut.openTab(connection: conn2, password: "pass2")

        let tab0VM = sut.tabs[0].viewModel
        let tab1VM = sut.tabs[1].viewModel

        // Mutate tab 0's VM state directly (independent of session)
        tab0VM.sortCriteria = .date
        tab0VM.sortAscending = false
        tab0VM.showHiddenFiles = true

        // Tab 1 should still have default state
        XCTAssertEqual(tab1VM.sortCriteria, .name, "Tab 1 sort criteria should be default")
        XCTAssertTrue(tab1VM.sortAscending, "Tab 1 sort ascending should be default")
        XCTAssertFalse(tab1VM.showHiddenFiles, "Tab 1 showHiddenFiles should be default")

        // When — switch to tab 1, then back to tab 0
        sut.switchToTab(at: 1)
        XCTAssertEqual(sut.activeTabIndex, 1)

        sut.switchToTab(at: 0)
        XCTAssertEqual(sut.activeTabIndex, 0)

        // Then — tab 0's VM state is preserved
        XCTAssertEqual(tab0VM.sortCriteria, .date,
                       "Tab 0's sort criteria must survive switching away and back")
        XCTAssertFalse(tab0VM.sortAscending,
                       "Tab 0's sort ascending must survive switching away and back")
        XCTAssertTrue(tab0VM.showHiddenFiles,
                      "Tab 0's showHiddenFiles must survive switching away and back")

        // Tab 1's state is unaffected
        XCTAssertEqual(tab1VM.sortCriteria, .name,
                       "Tab 1's state must not be affected by tab 0's mutations")
    }

    func testTabStateIndependence_closingTab_doesNotAffectOthers() async {
        // Given — 3 tabs with independent VMs
        let conn1 = makeConnection(name: "S1")
        let conn2 = makeConnection(name: "S2")
        let conn3 = makeConnection(name: "S3")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")

        let tab0VM = sut.tabs[0].viewModel
        let tab1VM = sut.tabs[1].viewModel
        let tab2VM = sut.tabs[2].viewModel

        // Mutate each tab's VM state
        tab0VM.sortCriteria = .date
        tab1VM.sortAscending = false
        tab2VM.showHiddenFiles = true

        // Verify initial state
        XCTAssertEqual(tab0VM.sortCriteria, .date)
        XCTAssertEqual(tab1VM.sortAscending, false)
        XCTAssertTrue(tab2VM.showHiddenFiles)

        // When — close the middle tab (index 1)
        sut.switchToTab(at: 1)
        await sut.closeTab(at: 1)

        // Then — only 2 tabs remain, unaffected
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(tab0VM.sortCriteria, .date,
                       "Tab 0's state must not change when tab 1 is closed")
        XCTAssertTrue(tab2VM.showHiddenFiles,
                      "Tab 2's state must not change when tab 1 is closed")
    }

    func testOpenTab_setsActiveToNewTab() {
        // Given — one tab already open
        let conn1 = makeConnection(name: "Existing")
        sut.openTab(connection: conn1, password: "p")
        XCTAssertEqual(sut.activeTabIndex, 0)

        // When — open a second tab
        let conn2 = makeConnection(name: "New")
        sut.openTab(connection: conn2, password: "p")

        // Then — active tab is the newly opened one
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertEqual(sut.activeTab?.connectionName, "New")
    }

    func testCloseActiveTab_switchesToAdjacent() async {
        // Given — 3 tabs, active is tab 1 (middle)
        let conn1 = makeConnection(name: "Left")
        let conn2 = makeConnection(name: "Middle")
        let conn3 = makeConnection(name: "Right")
        sut.openTab(connection: conn1, password: "p")
        sut.openTab(connection: conn2, password: "p")
        sut.openTab(connection: conn3, password: "p")
        sut.switchToTab(at: 1)
        XCTAssertEqual(sut.activeTabIndex, 1)

        // When — close the active (middle) tab
        await sut.closeTab(at: 1)

        // Then — active stays at index 1, which now points to "Right"
        XCTAssertEqual(sut.tabs.count, 2)
        XCTAssertEqual(sut.activeTabIndex, 1)
        XCTAssertEqual(sut.activeTab?.connectionName, "Right",
                       "After closing active middle tab, the next tab should become active")
    }
}
