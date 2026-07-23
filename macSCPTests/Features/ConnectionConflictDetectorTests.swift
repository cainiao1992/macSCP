//
//  ConnectionConflictDetectorTests.swift
//  macSCPTests
//
//  Unit tests for the shared ConnectionConflictDetector (W-1).
//  Covers the match predicate extracted from both import ViewModels:
//  case-insensitive host, exact username + port.
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionConflictDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func makeConnection(
        host: String,
        port: Int = 22,
        username: String = "root"
    ) -> Connection {
        Connection(name: host, host: host, port: port, username: username)
    }

    // MARK: - Match Found

    func testFindExisting_returnsMatchWhenHostUserPortAllMatch() {
        let existing = makeConnection(host: "example.com", port: 22, username: "root")

        let result = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "root",
            port: 22,
            in: [existing]
        )

        XCTAssertEqual(result?.id, existing.id)
    }

    // MARK: - No Match

    func testFindExisting_returnsNilWhenNoConnectionMatches() {
        let existing = makeConnection(host: "example.com", port: 22, username: "root")

        let result = ConnectionConflictDetector.findExisting(
            host: "other.com",
            username: "root",
            port: 22,
            in: [existing]
        )

        XCTAssertNil(result)
    }

    func testFindExisting_returnsNilForEmptyConnections() {
        let result = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "root",
            port: 22,
            in: []
        )

        XCTAssertNil(result)
    }

    // MARK: - Case-Insensitive Host

    func testFindExisting_matchesHostCaseInsensitively() {
        let existing = makeConnection(host: "Example.COM", port: 22, username: "root")

        let lower = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "root",
            port: 22,
            in: [existing]
        )
        let upper = ConnectionConflictDetector.findExisting(
            host: "EXAMPLE.COM",
            username: "root",
            port: 22,
            in: [existing]
        )

        XCTAssertEqual(lower?.id, existing.id)
        XCTAssertEqual(upper?.id, existing.id)
    }

    // MARK: - Different Port = No Match

    func testFindExisting_doesNotMatchWhenPortDiffers() {
        let existing = makeConnection(host: "example.com", port: 22, username: "root")

        let result = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "root",
            port: 2222,
            in: [existing]
        )

        XCTAssertNil(result)
    }

    // MARK: - Different Username = No Match

    func testFindExisting_doesNotMatchWhenUsernameDiffers() {
        let existing = makeConnection(host: "example.com", port: 22, username: "root")

        let result = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "admin",
            port: 22,
            in: [existing]
        )

        XCTAssertNil(result)
    }

    // MARK: - First Match Wins

    func testFindExisting_returnsFirstMatchWhenMultipleConnectionsPresent() {
        let first = makeConnection(host: "example.com", port: 22, username: "root")
        let second = makeConnection(host: "example.com", port: 22, username: "root")

        let result = ConnectionConflictDetector.findExisting(
            host: "example.com",
            username: "root",
            port: 22,
            in: [first, second]
        )

        XCTAssertEqual(result?.id, first.id)
    }
}
