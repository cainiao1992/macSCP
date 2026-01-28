//
//  DatabaseManagerTests.swift
//  macSCPTests
//
//  Unit tests for DatabaseManager
//

import SwiftData
import XCTest

@testable import macSCP

final class DatabaseManagerTests: XCTestCase {

    var databaseManager: DatabaseManager!

    override func setUp() {
        super.setUp()
        databaseManager = DatabaseManager.shared
    }

    override func tearDown() {
        databaseManager = nil
        super.tearDown()
    }

    // MARK: - createModelContainerWithRecovery Tests
    func testCreateModelContainerWithRecovery_succeeds() {
        // When
        let container = databaseManager.createModelContainerWithRecovery()
        // Then
        XCTAssertNotNil(container)
    }

    func testCreateModelContainerWithRecovery_returnsValidContainer() {
        // When
        let container = databaseManager.createModelContainerWithRecovery()
        // Then
        XCTAssertFalse(container.configurations.isEmpty)
    }

    func testCreateModelContainerWithRecovery_returnsSameSchemaTypes() {
        // When
        let container = databaseManager.createModelContainerWithRecovery()

        // Then
        let schema = container.schema
        let entityNames = schema.entities.map { $0.name }
        XCTAssertTrue(entityNames.contains("SSHConnection"))
        XCTAssertTrue(entityNames.contains("ConnectionFolder"))
    }
}
