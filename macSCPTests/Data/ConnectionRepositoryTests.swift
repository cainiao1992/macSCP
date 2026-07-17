//
//  ConnectionRepositoryTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionRepository
//

import XCTest
import SwiftData
@testable import macSCP

@MainActor
final class ConnectionRepositoryTests: XCTestCase {

    private static let testStore: macSCP.DataStore = {
        let schema = Schema([ConnectionEntity.self, FolderEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return macSCP.DataStore(modelContainer: container)
    }()

    private var sut: ConnectionRepository!

    override func setUpWithError() throws {
        sut = ConnectionRepository(dataStore: Self.testStore)
    }

    override func tearDownWithError() throws {
        sut = nil
    }

    // MARK: - fetchAll

    func testFetchAll_ReturnsSavedConnections() async throws {
        let before = try await sut.fetchAll().count
        try await sut.save(makeConnection(name: "Conn1"))
        try await sut.save(makeConnection(name: "Conn2"))

        let connections = try await sut.fetchAll()
        XCTAssertEqual(connections.count, before + 2)
    }

    // MARK: - save + fetchAll

    func testSave_ThenFetchAll() async throws {
        let conn = makeConnection(name: "New Connection")
        try await sut.save(conn)

        let all = try await sut.fetchAll()
        XCTAssertTrue(all.contains(where: { $0.name == "New Connection" }))
    }

    // MARK: - fetch(id:)

    func testFetch_ValidID() async throws {
        let conn = makeConnection(name: "Find Me")
        try await sut.save(conn)

        let fetched = try await sut.fetch(id: conn.id)
        XCTAssertEqual(fetched.name, "Find Me")
        XCTAssertEqual(fetched.host, "example.com")
    }

    func testFetch_InvalidID() async {
        do {
            _ = try await sut.fetch(id: UUID())
            XCTFail("Should have thrown")
        } catch {
            if case .entityNotFound = error as? AppError {
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - update

    func testUpdate_FieldsChanged() async throws {
        let conn = makeConnection(name: "Original")
        try await sut.save(conn)

        var updated = conn
        updated.name = "Updated"
        updated.host = "newhost.com"
        try await sut.update(updated)

        let fetched = try await sut.fetch(id: conn.id)
        XCTAssertEqual(fetched.name, "Updated")
        XCTAssertEqual(fetched.host, "newhost.com")
    }

    // MARK: - delete

    func testDelete_RemovesFromStore() async throws {
        let conn = makeConnection(name: "Delete Me")
        try await sut.save(conn)

        try await sut.delete(id: conn.id)

        let all = try await sut.fetchAll()
        XCTAssertFalse(all.contains(where: { $0.id == conn.id }))
    }

    func testDelete_InvalidID() async {
        do {
            try await sut.delete(id: UUID())
            XCTFail("Should have thrown")
        } catch {
            if case .entityNotFound = error as? AppError {
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - fetchConnections(forFolderId:)

    func testFetchConnections_NilFolder() async throws {
        let conn = makeConnection(name: "No Folder", folderId: nil)
        try await sut.save(conn)

        let results = try await sut.fetchConnections(forFolderId: nil)
        XCTAssertTrue(results.contains(where: { $0.id == conn.id }))
    }

    func testFetchConnections_WithFolderId() async throws {
        // Create a folder first
        let folderRepo = FolderRepository(dataStore: Self.testStore)
        let folder = Folder(name: "Test Folder")
        try await folderRepo.save(folder)

        let conn = makeConnection(name: "In Folder", folderId: folder.id)
        try await sut.save(conn)

        let results = try await sut.fetchConnections(forFolderId: folder.id)
        XCTAssertTrue(results.contains(where: { $0.id == conn.id }))
    }

    // MARK: - search

    func testSearch_MatchingName() async throws {
        let conn = makeConnection(name: "Production Server")
        try await sut.save(conn)

        let results = try await sut.search(query: "Production")
        XCTAssertTrue(results.contains(where: { $0.id == conn.id }))
    }

    func testSearch_MatchingHost() async throws {
        let conn = makeConnection(name: "UniqueName", host: "production.example.com")
        try await sut.save(conn)

        let results = try await sut.search(query: "production")
        XCTAssertTrue(results.contains(where: { $0.id == conn.id }))
    }

    func testSearch_MatchingUsername() async throws {
        let conn = makeConnection(name: "UniqueName", host: "unique.host", username: "deploy")
        try await sut.save(conn)

        let results = try await sut.search(query: "deploy")
        XCTAssertTrue(results.contains(where: { $0.id == conn.id }))
    }

    func testSearch_NoMatch() async throws {
        let results = try await sut.search(query: "nonexistent_xyz_123")
        XCTAssertFalse(results.contains(where: { $0.name == "nonexistent_xyz_123" }))
    }

    // MARK: - count

    func testCount() async throws {
        let initial = try await sut.count()

        try await sut.save(makeConnection(name: "Extra1"))
        try await sut.save(makeConnection(name: "Extra2"))

        let after = try await sut.count()
        XCTAssertEqual(after, initial + 2)
    }

    func testCount_ForFolderId() async throws {
        let folderRepo = FolderRepository(dataStore: Self.testStore)
        let folder = Folder(name: "Count Folder")
        try await folderRepo.save(folder)

        let initial = try await sut.count(forFolderId: folder.id)

        try await sut.save(makeConnection(name: "In Folder", folderId: folder.id))

        let after = try await sut.count(forFolderId: folder.id)
        XCTAssertEqual(after, initial + 1)
    }

    // MARK: - move

    func testMove_ToFolder() async throws {
        let folderRepo = FolderRepository(dataStore: Self.testStore)
        let folder = Folder(name: "Move Folder")
        try await folderRepo.save(folder)

        let conn = makeConnection(name: "Move Me", folderId: nil)
        try await sut.save(conn)

        try await sut.move(connectionId: conn.id, toFolderId: folder.id)

        let fetched = try await sut.fetch(id: conn.id)
        XCTAssertEqual(fetched.folderId, folder.id)
    }

    func testMove_ToNilFolder() async throws {
        let folderRepo = FolderRepository(dataStore: Self.testStore)
        let folder = Folder(name: "Move Folder")
        try await folderRepo.save(folder)

        let conn = makeConnection(name: "Move Me", folderId: folder.id)
        try await sut.save(conn)

        try await sut.move(connectionId: conn.id, toFolderId: nil)

        let fetched = try await sut.fetch(id: conn.id)
        XCTAssertNil(fetched.folderId)
    }

    // MARK: - Helpers

    private func makeConnection(
        name: String = "Test",
        host: String = "example.com",
        username: String = "user",
        folderId: UUID? = nil
    ) -> Connection {
        Connection(
            name: name, host: host, port: 22, username: username,
            folderId: folderId
        )
    }
}
