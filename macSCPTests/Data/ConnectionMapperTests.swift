//
//  ConnectionMapperTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionMapper
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionMapperTests: XCTestCase {

    // MARK: - toDomain

    func testToDomain_AllFieldsMapped() {
        let entity = ConnectionEntity(
            name: "Test Server",
            host: "example.com",
            port: 2222,
            username: "admin",
            authMethod: AuthMethod.privateKey.rawValue,
            privateKeyPath: "/home/user/.ssh/id_rsa",
            savePassword: true,
            connectionDescription: "Production",
            tags: ["prod", "web"],
            iconName: "server.rack",
            connectionType: ConnectionType.sftp.rawValue,
            s3Region: "us-east-1",
            s3Bucket: "my-bucket",
            s3Endpoint: "https://s3.example.com"
        )

        let domain = ConnectionMapper.toDomain(entity)

        XCTAssertEqual(domain.name, "Test Server")
        XCTAssertEqual(domain.host, "example.com")
        XCTAssertEqual(domain.port, 2222)
        XCTAssertEqual(domain.username, "admin")
        XCTAssertEqual(domain.authMethod, .privateKey)
        XCTAssertEqual(domain.privateKeyPath, "/home/user/.ssh/id_rsa")
        XCTAssertEqual(domain.savePassword, true)
        XCTAssertEqual(domain.description, "Production")
        XCTAssertEqual(domain.tags, ["prod", "web"])
        XCTAssertEqual(domain.iconName, "server.rack")
        XCTAssertEqual(domain.connectionType, .sftp)
        XCTAssertEqual(domain.s3Region, "us-east-1")
        XCTAssertEqual(domain.s3Bucket, "my-bucket")
        XCTAssertEqual(domain.s3Endpoint, "https://s3.example.com")
    }

    func testToDomain_AuthMethodFallback() {
        let entity = ConnectionEntity(
            name: "Test", host: "h", port: 22, username: "u",
            authMethod: "invalid_method"
        )
        let domain = ConnectionMapper.toDomain(entity)
        XCTAssertEqual(domain.authMethod, .password, "Invalid auth method should fallback to .password")
    }

    func testToDomain_ConnectionTypeFallback() {
        let entity = ConnectionEntity(
            name: "Test", host: "h", port: 22, username: "u",
            connectionType: "invalid_type"
        )
        let domain = ConnectionMapper.toDomain(entity)
        XCTAssertEqual(domain.connectionType, .sftp, "Invalid connection type should fallback to .sftp")
    }

    func testToDomain_WithFolder() {
        let folderId = UUID()
        let entity = ConnectionEntity(
            name: "Test", host: "h", port: 22, username: "u"
        )
        let folderEntity = FolderEntity(id: folderId, name: "Folder")
        entity.folder = folderEntity

        let domain = ConnectionMapper.toDomain(entity)
        XCTAssertEqual(domain.folderId, folderId)
    }

    func testToDomain_WithoutFolder() {
        let entity = ConnectionEntity(
            name: "Test", host: "h", port: 22, username: "u"
        )

        let domain = ConnectionMapper.toDomain(entity)
        XCTAssertNil(domain.folderId)
    }

    // MARK: - update

    func testUpdate_AllFieldsUpdated() {
        let entity = ConnectionEntity(
            name: "Old", host: "old.com", port: 22, username: "olduser"
        )

        let domain = Connection(
            name: "New", host: "new.com", port: 2222, username: "newuser",
            authMethod: .privateKey, privateKeyPath: "/key",
            savePassword: true, description: "Updated",
            tags: ["tag1"], iconName: "icon",
            connectionType: .s3, s3Region: "region",
            s3Bucket: "bucket",
            s3Endpoint: "endpoint"
        )

        ConnectionMapper.update(entity, from: domain)

        XCTAssertEqual(entity.name, "New")
        XCTAssertEqual(entity.host, "new.com")
        XCTAssertEqual(entity.port, 2222)
        XCTAssertEqual(entity.username, "newuser")
        XCTAssertEqual(entity.authMethod, "privateKey")
        XCTAssertEqual(entity.privateKeyPath, "/key")
        XCTAssertEqual(entity.savePassword, true)
        XCTAssertEqual(entity.connectionDescription, "Updated")
        XCTAssertEqual(entity.tags, ["tag1"])
        XCTAssertEqual(entity.iconName, "icon")
        XCTAssertEqual(entity.connectionType, "s3")
        XCTAssertEqual(entity.s3Bucket, "bucket")
        XCTAssertEqual(entity.s3Endpoint, "endpoint")
        XCTAssertEqual(entity.s3Region, "region")
    }

    func testUpdate_SetsCurrentDate() {
        let entity = ConnectionEntity(
            name: "Old", host: "old.com", port: 22, username: "u"
        )
        let domain = Connection(name: "New", host: "new.com", username: "u")

        let before = Date()
        ConnectionMapper.update(entity, from: domain)
        let after = Date()

        XCTAssertGreaterThanOrEqual(entity.updatedAt, before)
        XCTAssertLessThanOrEqual(entity.updatedAt, after)
    }

    // MARK: - toEntity

    func testToEntity_AllFieldsMatch() {
        let id = UUID()
        let domain = Connection(
            id: id,
            name: "Test", host: "example.com", port: 22, username: "user",
            authMethod: .password, savePassword: false,
            description: "desc", tags: ["t"], iconName: "i",
            connectionType: .s3, s3Region: "r",
            s3Bucket: "b",
            s3Endpoint: "e"
        )

        let entity = ConnectionMapper.toEntity(domain)

        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(entity.name, "Test")
        XCTAssertEqual(entity.host, "example.com")
        XCTAssertEqual(entity.port, 22)
        XCTAssertEqual(entity.username, "user")
        XCTAssertEqual(entity.authMethod, "password")
        XCTAssertEqual(entity.savePassword, false)
        XCTAssertEqual(entity.connectionDescription, "desc")
        XCTAssertEqual(entity.tags, ["t"])
        XCTAssertEqual(entity.iconName, "i")
        XCTAssertEqual(entity.connectionType, "s3")
        XCTAssertEqual(entity.s3Bucket, "b")
        XCTAssertEqual(entity.s3Endpoint, "e")
        XCTAssertEqual(entity.s3Region, "r")
    }

    func testToEntity_AuthMethodRawValue() {
        let domain = Connection(
            name: "Test", host: "h", username: "u",
            authMethod: .privateKey
        )
        let entity = ConnectionMapper.toEntity(domain)
        XCTAssertEqual(entity.authMethod, "privateKey")
    }
}
