//
//  FolderMapperTests.swift
//  macSCPTests
//
//  Unit tests for FolderMapper
//

import XCTest
@testable import macSCP

@MainActor
final class FolderMapperTests: XCTestCase {

    // MARK: - toDomain

    func testToDomain_AllFieldsMapped() {
        let entity = FolderEntity(
            name: "Servers",
            displayOrder: 5
        )

        let domain = FolderMapper.toDomain(entity)

        XCTAssertEqual(domain.id, entity.id)
        XCTAssertEqual(domain.name, "Servers")
        XCTAssertEqual(domain.displayOrder, 5)
        XCTAssertEqual(domain.createdAt, entity.createdAt)
        XCTAssertEqual(domain.updatedAt, entity.updatedAt)
    }

    func testToDomain_DefaultValues() {
        let entity = FolderEntity(name: "Test")
        let domain = FolderMapper.toDomain(entity)
        XCTAssertEqual(domain.name, "Test")
        XCTAssertEqual(domain.displayOrder, 0)
    }

    // MARK: - update

    func testUpdate_AllFieldsUpdated() {
        let entity = FolderEntity(name: "Old Name", displayOrder: 1)

        let domain = Folder(name: entity.name, displayOrder: 10)

        FolderMapper.update(entity, from: domain)

        XCTAssertEqual(entity.name, "Old Name")
        XCTAssertEqual(entity.displayOrder, 10)
    }

    func testUpdate_SetsCurrentDate() {
        let entity = FolderEntity(name: "Test")
        let domain = Folder(name: "New Name", displayOrder: 3)

        let before = Date()
        FolderMapper.update(entity, from: domain)
        let after = Date()

        XCTAssertGreaterThanOrEqual(entity.updatedAt, before)
        XCTAssertLessThanOrEqual(entity.updatedAt, after)
    }

    // MARK: - toEntity

    func testToEntity_AllFieldsMatch() {
        let id = UUID()
        let domain = Folder(
            id: id,
            name: "Production",
            displayOrder: 7
        )

        let entity = FolderMapper.toEntity(domain)

        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(entity.name, "Production")
        XCTAssertEqual(entity.displayOrder, 7)
    }
}
