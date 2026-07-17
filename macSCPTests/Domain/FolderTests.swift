//
//  FolderTests.swift
//  macSCPTests
//
//  Unit tests for Folder domain model
//

import XCTest
@testable import macSCP

@MainActor
final class FolderTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInit_NonNilID() {
        let folder = Folder(name: "Test")
        XCTAssertNotNil(folder.id)
    }

    func testDefaultInit_DisplayOrderZero() {
        let folder = Folder(name: "Test")
        XCTAssertEqual(folder.displayOrder, 0)
    }

    func testDefaultInit_DatesSet() {
        let before = Date()
        let folder = Folder(name: "Test")
        let after = Date()
        XCTAssertGreaterThanOrEqual(folder.createdAt, before)
        XCTAssertLessThanOrEqual(folder.createdAt, after)
        XCTAssertGreaterThanOrEqual(folder.updatedAt, before)
        XCTAssertLessThanOrEqual(folder.updatedAt, after)
    }

    // MARK: - isValid

    func testIsValid_NonBlankName() {
        let folder = Folder(name: "Servers")
        XCTAssertTrue(folder.isValid)
    }

    func testIsValid_EmptyName() {
        let folder = Folder(name: "")
        XCTAssertFalse(folder.isValid)
    }

    func testIsValid_WhitespaceOnlyName() {
        let folder = Folder(name: "   ")
        XCTAssertFalse(folder.isValid)
    }

    // MARK: - withUpdatedTimestamp

    func testWithUpdatedTimestamp() {
        let folder = Folder(name: "Test", displayOrder: 3)
        let beforeDate = folder.updatedAt

        Thread.sleep(forTimeInterval: 0.01)

        let updated = folder.withUpdatedTimestamp()

        XCTAssertEqual(updated.id, folder.id)
        XCTAssertEqual(updated.name, folder.name)
        XCTAssertEqual(updated.displayOrder, folder.displayOrder)
        XCTAssertEqual(updated.createdAt, folder.createdAt)
        XCTAssertGreaterThan(updated.updatedAt, beforeDate)
    }

    // MARK: - Codable

    func testCodable_RoundTrip() {
        let folder = Folder(
            name: "Production", displayOrder: 5
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try! encoder.encode(folder)
        let decoded = try! decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.id, folder.id)
        XCTAssertEqual(decoded.name, folder.name)
        XCTAssertEqual(decoded.displayOrder, folder.displayOrder)
        XCTAssertEqual(decoded.createdAt, folder.createdAt)
        XCTAssertEqual(decoded.updatedAt, folder.updatedAt)
    }

    // MARK: - Hashable

    func testHashable_SameID_SameFields_Equal() {
        let id = UUID()
        let now = Date()
        let folder1 = Folder(id: id, name: "A", displayOrder: 1, createdAt: now, updatedAt: now)
        let folder2 = Folder(id: id, name: "A", displayOrder: 1, createdAt: now, updatedAt: now)
        XCTAssertEqual(folder1, folder2)
    }

    func testHashable_DifferentFields_NotEqual() {
        let id = UUID()
        let folder1 = Folder(id: id, name: "A", displayOrder: 1)
        let folder2 = Folder(id: id, name: "B", displayOrder: 2)
        XCTAssertNotEqual(folder1, folder2)
    }

    func testHashable_DifferentID_NotEqual() {
        let folder1 = Folder(id: UUID(), name: "Same", displayOrder: 1)
        let folder2 = Folder(id: UUID(), name: "Same", displayOrder: 1)
        XCTAssertNotEqual(folder1, folder2)
    }
}
