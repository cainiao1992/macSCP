//
//  ConnectionListViewModelTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionListViewModel
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionListViewModelTests: XCTestCase {
    var sut: ConnectionListViewModel!
    var mockConnectionRepository: MockConnectionRepository!
    var mockFolderRepository: MockFolderRepository!
    var mockKeychainService: MockKeychainService!
    var mockWindowManager: WindowManager!

    override func setUp() async throws {
        try await super.setUp()
        mockConnectionRepository = MockConnectionRepository()
        mockFolderRepository = MockFolderRepository()
        mockKeychainService = MockKeychainService()
        mockWindowManager = WindowManager.shared

        await mockConnectionRepository.reset()
        await mockFolderRepository.reset()
        await mockKeychainService.reset()

        sut = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: TabManager(
                browserViewModelFactory: { _, _ in
                    fatalError("TabManager factory called in test — not expected")
                },
                terminalViewModelFactory: { _, _ in
                    fatalError("Terminal factory called in test — not expected")
                }
            )
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockConnectionRepository = nil
        mockFolderRepository = nil
        mockKeychainService = nil
        mockWindowManager = nil
        try await super.tearDown()
    }

    // MARK: - Load Data Tests

    func testLoadData_Success() async {
        // Given
        let connection = Connection(name: "Test", host: "test.com", username: "user")
        let folder = Folder(name: "Test Folder")
        mockConnectionRepository.mockConnections = [connection]
        mockFolderRepository.mockFolders = [folder]

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.connections.count, 1)
        XCTAssertEqual(sut.folders.count, 1)
        XCTAssertTrue(mockConnectionRepository.fetchAllCalled)
        XCTAssertTrue(mockFolderRepository.fetchAllCalled)
        XCTAssertTrue(sut.state.isSuccess)
    }

    func testLoadData_Error() async {
        // Given
        mockConnectionRepository.mockError = AppError.fetchFailed("test")

        // When
        await sut.loadData()

        // Then
        XCTAssertTrue(sut.state.isError)
    }

    // MARK: - Connection Tests

    func testSaveConnection_Success() async {
        // Given
        let connection = Connection(name: "Test", host: "test.com", username: "user", savePassword: true)

        // When
        await sut.saveConnection(connection, password: "secret")

        // Then
        XCTAssertTrue(mockConnectionRepository.saveCalled)
        XCTAssertTrue(mockKeychainService.savePasswordCalled)
        XCTAssertEqual(mockKeychainService.lastSavedPassword, "secret")
    }

    func testDeleteConnection_Success() async {
        // Given
        let connection = Connection(name: "Test", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection]

        // When
        await sut.deleteConnection(connection)

        // Then
        XCTAssertTrue(mockConnectionRepository.deleteCalled)
        XCTAssertEqual(mockConnectionRepository.lastDeletedId, connection.id)
    }

    // MARK: - Favorite Tests

    func testToggleFavorite_Success() async {
        // Given
        let connection = Connection(name: "Test", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection]
        await sut.loadData()

        // When
        await sut.toggleFavorite(connection)

        // Then
        XCTAssertTrue(mockConnectionRepository.toggleFavoriteCalled)
        XCTAssertEqual(mockConnectionRepository.lastToggledFavoriteId, connection.id)
        XCTAssertEqual(sut.connections.first?.isFavorite, true)
    }

    func testFavoriteConnections_Filter() async {
        // Given
        let favConnection = Connection(name: "Favorite", host: "fav.com", username: "user", isFavorite: true)
        let normalConnection = Connection(name: "Normal", host: "normal.com", username: "user")
        mockConnectionRepository.mockConnections = [favConnection, normalConnection]
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.favoriteConnections.count, 1)
        XCTAssertEqual(sut.favoriteConnections.first?.name, "Favorite")
    }

    // MARK: - PASS-02 Tests

    func testAttemptConnect_AuthFailure_KeepsSheetOpen_SetsConnectionError() async {
        // Given
        let mockSession = MockSFTPSession()
        await mockSession.setMockError(AppError.authenticationFailed)

        let connection = Connection(name: "Test", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection]

        let testVM = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: TabManager(
                browserViewModelFactory: { _, _ in
                    fatalError("Should not open tab on auth failure")
                },
                terminalViewModelFactory: { _, _ in
                    fatalError("Terminal factory called in test — not expected")
                }
            ),
            makeSFTPSession: { mockSession }
        )

        await testVM.loadData()
        testVM.isShowingPasswordPrompt = true
        testVM.connectionToConnect = connection

        // When
        await testVM.attemptConnect(connection, password: "wrong")

        // Then
        XCTAssertTrue(testVM.isShowingPasswordPrompt)
        XCTAssertNotNil(testVM.connectionError)
    }

    func testAttemptConnect_Success_OpensTab_UpdatesLastUsedAt_DismissesSheet() async {
        // Given
        let mockSession = MockSFTPSession()

        let connection = Connection(name: "Test", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection]

        var openedConnections: [Connection] = []
        let recordingTabManager = TabManager(
            browserViewModelFactory: { conn, password in
                openedConnections.append(conn)
                return FileBrowserViewModel(
                    connection: conn,
                    sftpSession: MockSFTPSession(),
                    fileRepository: MockFileRepository(),
                    clipboardService: ClipboardService.shared,
                    password: password
                )
            },
            terminalViewModelFactory: { _, _ in
                fatalError("Terminal factory called in test — not expected")
            }
        )

        let testVM = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: recordingTabManager,
            makeSFTPSession: { mockSession }
        )

        await testVM.loadData()
        testVM.isShowingPasswordPrompt = true
        testVM.connectionToConnect = connection

        // When
        await testVM.attemptConnect(connection, password: "right")

        // Then
        XCTAssertFalse(testVM.isShowingPasswordPrompt)
        XCTAssertNil(testVM.connectionError)
        XCTAssertTrue(mockConnectionRepository.updateLastUsedAtCalled)
        XCTAssertEqual(openedConnections.count, 1)
        XCTAssertEqual(openedConnections.first?.id, connection.id)
    }

    // MARK: - Folder Tests

    func testCreateFolder_Success() async {
        // Given
        let folderName = "New Folder"

        // When
        await sut.createFolder(name: folderName)

        // Then
        XCTAssertTrue(mockFolderRepository.saveCalled)
        XCTAssertEqual(mockFolderRepository.lastSavedFolder?.name, folderName)
    }

    func testDeleteFolder_Success() async {
        // Given
        let folder = Folder(name: "Test Folder")
        mockFolderRepository.mockFolders = [folder]
        sut.selectedSidebarItem = .folder(folder.id)

        // When
        await sut.deleteFolder(folder)

        // Then
        XCTAssertTrue(mockFolderRepository.deleteCalled)
        XCTAssertEqual(mockFolderRepository.lastDeletedId, folder.id)
        XCTAssertEqual(sut.selectedSidebarItem, .allConnections)
    }

    // MARK: - Filter Tests

    func testFilteredConnections_SearchText() async {
        // Given
        let connection1 = Connection(name: "Production", host: "prod.com", username: "admin")
        let connection2 = Connection(name: "Development", host: "dev.com", username: "dev")
        mockConnectionRepository.mockConnections = [connection1, connection2]
        await sut.loadData()

        // When
        sut.searchText = "prod"

        // Then
        XCTAssertEqual(sut.filteredConnections.count, 1)
        XCTAssertEqual(sut.filteredConnections.first?.name, "Production")
    }

    func testFilteredConnections_ByFolder() async {
        // Given
        let folder = Folder(name: "Test Folder")
        let connection1 = Connection(name: "In Folder", host: "test.com", username: "user", folderId: folder.id)
        let connection2 = Connection(name: "No Folder", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection1, connection2]
        mockFolderRepository.mockFolders = [folder]
        await sut.loadData()

        // When
        sut.selectedSidebarItem = .folder(folder.id)

        // Then
        XCTAssertEqual(sut.filteredConnections.count, 1)
        XCTAssertEqual(sut.filteredConnections.first?.name, "In Folder")
    }

    // MARK: - Connection Count Tests

    func testConnectionCount_ForFolder() async {
        // Given
        let folder = Folder(name: "Test Folder")
        let connection1 = Connection(name: "Test 1", host: "test.com", username: "user", folderId: folder.id)
        let connection2 = Connection(name: "Test 2", host: "test.com", username: "user", folderId: folder.id)
        let connection3 = Connection(name: "Test 3", host: "test.com", username: "user")
        mockConnectionRepository.mockConnections = [connection1, connection2, connection3]
        mockFolderRepository.mockFolders = [folder]
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.connectionCount(for: folder.id), 2)
        XCTAssertEqual(sut.totalConnectionCount, 3)
    }

    // MARK: - Test Connection Tests

    func testTestConnection_Success() async {
        // Given
        let mockSession = MockSFTPSession()
        let connection = Connection(name: "Test", host: "test.com", username: "user")

        let testVM = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: TabManager(
                browserViewModelFactory: { _, _ in fatalError("not expected") },
                terminalViewModelFactory: { _, _ in fatalError("not expected") }
            ),
            makeSFTPSession: { mockSession }
        )

        // When
        await testVM.testConnection(connection, password: "password")

        // Then
        XCTAssertEqual(testVM.testConnectionState, .success)
    }

    func testTestConnection_Failure() async {
        // Given
        let mockSession = MockSFTPSession()
        await mockSession.setMockError(AppError.authenticationFailed)
        let connection = Connection(name: "Test", host: "test.com", username: "user")

        let testVM = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: TabManager(
                browserViewModelFactory: { _, _ in fatalError("not expected") },
                terminalViewModelFactory: { _, _ in fatalError("not expected") }
            ),
            makeSFTPSession: { mockSession }
        )

        // When
        await testVM.testConnection(connection, password: "wrong")

        // Then
        if case .failure(let msg) = testVM.testConnectionState {
            XCTAssertTrue(msg.contains("Authentication") || msg.contains("failed") || !msg.isEmpty)
        } else {
            XCTFail("Expected failure state")
        }
    }

    func testResetTestConnectionState() async {
        // Given
        let testVM = ConnectionListViewModel(
            connectionRepository: mockConnectionRepository,
            folderRepository: mockFolderRepository,
            keychainService: mockKeychainService,
            windowManager: mockWindowManager,
            tabManager: TabManager(
                browserViewModelFactory: { _, _ in fatalError("not expected") },
                terminalViewModelFactory: { _, _ in fatalError("not expected") }
            )
        )

        // When
        testVM.resetTestConnectionState()

        // Then
        XCTAssertEqual(testVM.testConnectionState, .idle)
    }
}
