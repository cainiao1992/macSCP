//
//  FolderRepositoryTests.swift
//  macSCPTests
//
//  Unit tests for FolderRepository
//

import XCTest
import SwiftData
@testable import macSCP

@MainActor
final class FolderRepositoryTests: XCTestCase {

    private static let testStore: macSCP.DataStore = {
        let schema = Schema([ConnectionEntity.self, FolderEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return macSCP.DataStore(modelContainer: container)
    }()

    private var sut: FolderRepository!

    override func setUpWithError() throws {
        sut = FolderRepository(dataStore: Self.testStore)
    }

    override func tearDownWithError() throws {
        sut = nil
    }

    // MARK: - fetchAll

    func testFetchAll_ReturnsResults() async throws {
        try await sut.save(Folder(name: "Test Folder"))
        let folders = try await sut.fetchAll()
        XCTAssertFalse(folders.isEmpty)
    }

    // MARK: - save + fetchAll

    func testSave_ThenFetchAll() async throws {
        let initial = try await sut.fetchAll()
        let folder = Folder(name: "New Folder")
        try await sut.save(folder)

        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, initial.count + 1)
        XCTAssertTrue(all.contains(where: { $0.name == "New Folder" }))
    }

    // MARK: - fetch(id:)

    func testFetch_ValidID() async throws {
        let folder = Folder(name: "Find Me", displayOrder: 3)
        try await sut.save(folder)

        let fetched = try await sut.fetch(id: folder.id)
        XCTAssertEqual(fetched.name, "Find Me")
        XCTAssertEqual(fetched.displayOrder, 3)
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
        let folder = Folder(name: "Original", displayOrder: 1)
        try await sut.save(folder)

        var updated = folder
        updated.name = "Updated"
        updated.displayOrder = 5
        try await sut.update(updated)

        let fetched = try await sut.fetch(id: folder.id)
        XCTAssertEqual(fetched.name, "Updated")
        XCTAssertEqual(fetched.displayOrder, 5)
    }

    // MARK: - delete

    func testDelete_RemovesFromStore() async throws {
        let folder = Folder(name: "Delete Me")
        try await sut.save(folder)

        try await sut.delete(id: folder.id)

        do {
            _ = try await sut.fetch(id: folder.id)
            XCTFail("Should have thrown entity not found")
        } catch let error as AppError {
            if case .entityNotFound = error {
            } else {
                XCTFail("Unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - exists

    func testExists_ExistingName() async throws {
        let folder = Folder(name: "UniqueName12345")
        try await sut.save(folder)

        let result = try await sut.exists(name: "UniqueName12345")
        XCTAssertTrue(result)
    }

    func testExists_NonExistingName() async throws {
        let result = try await sut.exists(name: "NonExistentFolder98765")
        XCTAssertFalse(result)
    }

    // MARK: - count

    func testCount() async throws {
        let initial = try await sut.count()

        try await sut.save(Folder(name: "Extra1"))
        try await sut.save(Folder(name: "Extra2"))

        let after = try await sut.count()
        XCTAssertEqual(after, initial + 2)
    }

    // MARK: - updateOrder

    func testUpdateOrder() async throws {
        let folder1 = Folder(name: "A", displayOrder: 0)
        let folder2 = Folder(name: "B", displayOrder: 0)
        try await sut.save(folder1)
        try await sut.save(folder2)

        var reordered1 = folder1
        reordered1.displayOrder = 5
        var reordered2 = folder2
        reordered2.displayOrder = 10

        try await sut.updateOrder([reordered1, reordered2])

        let fetched1 = try await sut.fetch(id: folder1.id)
        let fetched2 = try await sut.fetch(id: folder2.id)
        XCTAssertEqual(fetched1.displayOrder, 5)
        XCTAssertEqual(fetched2.displayOrder, 10)
    }
}
