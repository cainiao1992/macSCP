//
//  SSHConnectionTests.swift
//  macSCPTests
//
//  Unit tests for SSHConnection model
//

import XCTest
@testable import macSCP

final class SSHConnectionTests: XCTestCase {

    func testSSHConnectionInitialization() {
        // Given
        let name = "Test Server"
        let host = "192.168.1.1"
        let port = 22
        let username = "testuser"

        // When
        let connection = SSHConnection(
            name: name,
            host: host,
            port: port,
            username: username
        )

        // Then
        XCTAssertEqual(connection.name, name)
        XCTAssertEqual(connection.host, host)
        XCTAssertEqual(connection.port, port)
        XCTAssertEqual(connection.username, username)
        XCTAssertEqual(connection.authType, .password) // Default
        XCTAssertFalse(connection.shouldSavePassword)
        XCTAssertNotNil(connection.id)
    }

    func testSSHConnectionWithSSHKey() {
        // Given
        let keyPath = "~/.ssh/id_rsa"

        // When
        let connection = SSHConnection(
            name: "Key Server",
            host: "example.com",
            port: 22,
            username: "admin",
            authenticationType: .key,
            privateKeyPath: keyPath
        )

        // Then
        XCTAssertEqual(connection.authType, .key)
        XCTAssertEqual(connection.privateKeyPath, keyPath)
    }

    func testDisplayDescription() {
        // Given
        let connection = SSHConnection(
            name: "Test",
            host: "localhost",
            port: 22,
            username: "user",
            description: "Test description"
        )

        // Then
        XCTAssertEqual(connection.displayDescription, "Test description")

        // When setting empty description
        connection.displayDescription = ""

        // Then
        XCTAssertEqual(connection.connectionDescription, nil)
    }

    func testConnectionTags() {
        // Given
        let tags = ["production", "database", "critical"]
        let connection = SSHConnection(
            name: "Test",
            host: "localhost",
            port: 22,
            username: "user",
            tags: tags
        )

        // Then
        XCTAssertEqual(connection.connectionTags, tags)

        // When setting empty tags
        connection.connectionTags = []

        // Then
        XCTAssertNil(connection.tags)
    }

    func testDisplayIcon() {
        // Given
        let connection = SSHConnection(
            name: "Test",
            host: "localhost",
            port: 22,
            username: "user"
        )

        // Then - default icon
        XCTAssertEqual(connection.displayIcon, "server.rack")

        // When setting custom icon
        connection.iconName = "desktopcomputer"

        // Then
        XCTAssertEqual(connection.displayIcon, "desktopcomputer")
    }

    func testSavePasswordFlag() {
        // Given
        let connection = SSHConnection(
            name: "Test",
            host: "localhost",
            port: 22,
            username: "user",
            savePassword: true
        )

        // Then
        XCTAssertTrue(connection.shouldSavePassword)

        // When
        connection.shouldSavePassword = false

        // Then
        XCTAssertFalse(connection.savePassword ?? true)
    }
}
