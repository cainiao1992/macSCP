//
//  DatabaseManagerTests.swift
//  macSCPTests
//
//  Unit tests for DatabaseManager
//

import XCTest
import SwiftData
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

    // MARK: - createModelContainer Tests

    func testCreateModelContainer_succeeds() {
        // When
        do {
            let container = try databaseManager.createModelContainer()

            // Then
            XCTAssertNotNil(container)
        } catch {
            XCTFail("createModelContainer should not throw: \(error)")
        }
    }

    func testCreateModelContainer_returnsValidContainer() {
        // When
        do {
            let container = try databaseManager.createModelContainer()

            // Then
            XCTAssertFalse(container.configurations.isEmpty)
        } catch {
            XCTFail("createModelContainer should not throw: \(error)")
        }
    }

    // MARK: - resetDatabase Tests

    func testResetDatabase_doesNotCrash() {
        // When / Then - should not crash
        databaseManager.resetDatabase()
    }
}
