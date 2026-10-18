//
//  ConnectionCRUDCoordinatorTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionCRUDCoordinator — proves independent testability (VM-SPLIT-03)
//  of the connection CRUD operations (save/update/delete/move).
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionCRUDCoordinatorTests: XCTestCase {
    // MARK: - Dependencies
    var mockConnectionRepository: MockConnectionRepository!
    var mockKeychainService: MockKeychainService!
    var sut: ConnectionCRUDCoordinator!

    // MARK: - Captured Callback State
    var reloadDataCalled = false
    var capturedError: AppError?
    var movedConnection: Connection?
    var movedFolderId: UUID?

    let testConnection = Connection(
        name: "Test Server",
        host: "test.example.com",
        username: "user",
        savePassword: true
    )

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockConnectionRepository = MockConnectionRepository()
        await mockConnectionRepository.reset()
        mockKeychainService = MockKeychainService()
        mockKeychainService.reset()
        reloadDataCalled = false
        capturedError = nil
        movedConnection = nil
        movedFolderId = nil

        sut = ConnectionCRUDCoordinator(
            connectionRepository: mockConnectionRepository,
            keychainService: mockKeychainService,
            onReloadData: { [weak self] in self?.reloadDataCalled = true },
            onError: { [weak self] error in self?.capturedError = error },
            onConnectionMoved: { [weak self] connection, folderId in
                self?.movedConnection = connection
                self?.movedFolderId = folderId
            }
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockConnectionRepository = nil
        mockKeychainService = nil
        try await super.tearDown()
    }

    // MARK: - Independent Instantiation (VM-SPLIT-03)

    func testConnectionCRUDCoordinator_CanBeInstantiatedWithMockDeps() {
        XCTAssertNotNil(sut)
    }

    // MARK: - saveConnection: success → repo.save + keychain.savePassword + returns true

    func testSaveConnection_Success_CallsRepoAndKeychainAndReturnsTrue() async {
        // When
        let result = await sut.saveConnection(testConnection, password: "secret")

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockConnectionRepository.saveCalled)
        XCTAssertEqual(mockConnectionRepository.lastSavedConnection?.id, testConnection.id)
        XCTAssertTrue(mockKeychainService.savePasswordCalled)
        XCTAssertEqual(mockKeychainService.lastSavedPassword, "secret")
        XCTAssertTrue(reloadDataCalled)
    }

    // MARK: - saveConnection: repository throws → returns false + onError

    func testSaveConnection_WhenRepoThrows_ReturnsFalseAndCallsOnError() async {
        // Given
        mockConnectionRepository.mockError = AppError.fetchFailed("db error")

        // When
        let result = await sut.saveConnection(testConnection, password: "secret")

        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(capturedError)
        XCTAssertFalse(reloadDataCalled)
    }

    // MARK: - deleteConnection: repo.delete + keychain.deletePassword + onReloadData

    func testDeleteConnection_CallsRepoDeleteAndKeychainDeleteAndReload() async {
        // When
        let result = await sut.deleteConnection(testConnection)

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockConnectionRepository.deleteCalled)
        XCTAssertEqual(mockConnectionRepository.lastDeletedId, testConnection.id)
        XCTAssertTrue(mockKeychainService.deletePasswordCalled)
        XCTAssertTrue(reloadDataCalled)
    }

    // MARK: - moveConnection: repo.move + onConnectionMoved + returns true

    func testMoveConnection_CallsRepoMoveAndInvokesOnConnectionMoved() async {
        // Given
        let targetFolder = Folder(name: "Target")

        // When
        let result = await sut.moveConnection(testConnection, to: targetFolder)

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockConnectionRepository.moveCalled)
        XCTAssertEqual(mockConnectionRepository.lastMoveConnectionId, testConnection.id)
        XCTAssertEqual(mockConnectionRepository.lastMoveFolderId, targetFolder.id)
        XCTAssertEqual(movedConnection?.id, testConnection.id)
        XCTAssertEqual(movedFolderId, targetFolder.id)
    }
}
