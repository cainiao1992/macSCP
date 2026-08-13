//
//  ConnectionTests.swift
//  macSCPTests
//
//  Unit tests for Connection domain model
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionTests: XCTestCase {

    // MARK: - displayHost

    func testDisplayHost_SFTP_DefaultPort() {
        let conn = makeSFTPConnection(port: 22)
        XCTAssertEqual(conn.displayHost, "example.com")
    }

    func testDisplayHost_SFTP_CustomPort() {
        let conn = makeSFTPConnection(port: 2222)
        XCTAssertEqual(conn.displayHost, "example.com:2222")
    }

    func testDisplayHost_S3_WithEndpoint() {
        let conn = makeS3Connection(s3Endpoint: "s3.us-west-2.amazonaws.com")
        XCTAssertEqual(conn.displayHost, "s3.us-west-2.amazonaws.com")
    }

    func testDisplayHost_S3_EmptyEndpoint() {
        let conn = makeS3Connection(s3Endpoint: "")
        XCTAssertEqual(conn.displayHost, "my-bucket")
    }

    func testDisplayHost_S3_NilEndpoint_NilBucket() {
        let conn = Connection(
            name: "Test S3", host: "", username: "access",
            connectionType: .s3
        )
        XCTAssertEqual(conn.displayHost, "S3")
    }

    func testDisplayHost_S3_NilEndpoint_WithBucket() {
        let conn = makeS3Connection(s3Bucket: "my-bucket", s3Endpoint: nil)
        XCTAssertEqual(conn.displayHost, "my-bucket")
    }

    // MARK: - connectionString

    func testConnectionString_SFTP_DefaultPort() {
        let conn = makeSFTPConnection(port: 22)
        XCTAssertEqual(conn.connectionString, "user@example.com")
    }

    func testConnectionString_SFTP_CustomPort() {
        let conn = makeSFTPConnection(port: 2222)
        XCTAssertEqual(conn.connectionString, "user@example.com:2222")
    }

    func testConnectionString_S3_WithBucket() {
        let conn = makeS3Connection(s3Bucket: "my-bucket")
        XCTAssertEqual(conn.connectionString, "s3://my-bucket")
    }

    func testConnectionString_S3_NoBucket() {
        let conn = Connection(
            name: "Test S3", host: "", username: "access",
            connectionType: .s3
        )
        XCTAssertEqual(conn.connectionString, "S3")
    }

    // MARK: - hasDescription

    func testHasDescription_Nil() {
        let conn = makeSFTPConnection()
        XCTAssertFalse(conn.hasDescription)
    }

    func testHasDescription_EmptyString() {
        var conn = makeSFTPConnection()
        conn.description = ""
        XCTAssertFalse(conn.hasDescription)
    }

    func testHasDescription_WhitespaceOnly() {
        var conn = makeSFTPConnection()
        conn.description = "   "
        XCTAssertFalse(conn.hasDescription)
    }

    func testHasDescription_NonEmpty() {
        var conn = makeSFTPConnection()
        conn.description = "My server"
        XCTAssertTrue(conn.hasDescription)
    }

    // MARK: - hasTags

    func testHasTags_Empty() {
        let conn = makeSFTPConnection(tags: [])
        XCTAssertFalse(conn.hasTags)
    }

    func testHasTags_NonEmpty() {
        let conn = makeSFTPConnection(tags: ["prod"])
        XCTAssertTrue(conn.hasTags)
    }

    // MARK: - isValid (SFTP)

    func testIsValid_SFTP_Valid() {
        let conn = makeSFTPConnection()
        XCTAssertTrue(conn.isValid)
    }

    func testIsValid_SFTP_MissingName() {
        let conn = makeSFTPConnection(name: "")
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_MissingHost() {
        let conn = makeSFTPConnection(host: "")
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_MissingUsername() {
        let conn = makeSFTPConnection(username: "")
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_PortZero() {
        let conn = makeSFTPConnection(port: 0)
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_PortTooHigh() {
        let conn = makeSFTPConnection(port: 65536)
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_NegativePort() {
        let conn = makeSFTPConnection(port: -1)
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_PrivateKeyAuth_NilPath() {
        let conn = makeSFTPConnection(authMethod: .privateKey, privateKeyPath: nil)
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_SFTP_PrivateKeyAuth_WithKeyPath() {
        let conn = makeSFTPConnection(authMethod: .privateKey, privateKeyPath: "/home/user/.ssh/id_rsa")
        XCTAssertTrue(conn.isValid)
    }

    // MARK: - isValid (S3)

    func testIsValid_S3_Valid() {
        let conn = makeS3Connection()
        XCTAssertTrue(conn.isValid)
    }

    func testIsValid_S3_MissingBucket() {
        let conn = Connection(
            name: "Test", host: "", username: "access",
            connectionType: .s3, s3Bucket: nil
        )
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_S3_MissingUsername() {
        let conn = Connection(
            name: "Test", host: "", username: "",
            connectionType: .s3, s3Bucket: "bucket"
        )
        XCTAssertFalse(conn.isValid)
    }

    func testIsValid_S3_MissingName() {
        let conn = Connection(
            name: "", host: "", username: "access",
            connectionType: .s3, s3Bucket: "bucket"
        )
        XCTAssertFalse(conn.isValid)
    }

    // MARK: - validationErrors (SFTP)

    func testValidationErrors_SFTP_Valid() {
        let conn = makeSFTPConnection()
        XCTAssertTrue(conn.validationErrors.isEmpty)
    }

    func testValidationErrors_SFTP_MissingName() {
        let conn = makeSFTPConnection(name: "")
        XCTAssertTrue(conn.validationErrors.contains("Name is required"))
    }

    func testValidationErrors_SFTP_MissingHost() {
        let conn = makeSFTPConnection(host: "")
        XCTAssertTrue(conn.validationErrors.contains("Host is required"))
    }

    func testValidationErrors_SFTP_MissingUsername() {
        let conn = makeSFTPConnection(username: "")
        XCTAssertTrue(conn.validationErrors.contains("Username is required"))
    }

    func testValidationErrors_SFTP_PortOutOfRange() {
        let conn = makeSFTPConnection(port: 0)
        XCTAssertTrue(conn.validationErrors.contains("Port must be between 1 and 65535"))
    }

    func testValidationErrors_SFTP_PrivateKeyAuth_NoPath() {
        let conn = makeSFTPConnection(authMethod: .privateKey, privateKeyPath: nil)
        XCTAssertTrue(conn.validationErrors.contains("Private key path is required for key authentication"))
    }

    // MARK: - validationErrors (S3)

    func testValidationErrors_S3_MissingName() {
        let conn = Connection(name: "", host: "", username: "access", connectionType: .s3, s3Bucket: "bucket")
        XCTAssertTrue(conn.validationErrors.contains("Name is required"))
    }

    func testValidationErrors_S3_MissingUsername() {
        let conn = Connection(name: "Test", host: "", username: "", connectionType: .s3, s3Bucket: "bucket")
        XCTAssertTrue(conn.validationErrors.contains("Access Key ID is required"))
    }

    func testValidationErrors_S3_MissingBucket() {
        let conn = Connection(name: "Test", host: "", username: "access", connectionType: .s3, s3Bucket: nil)
        XCTAssertTrue(conn.validationErrors.contains("Bucket name is required"))
    }

    // MARK: - isS3Connection / isSFTPConnection

    func testIsSFTPConnection() {
        let conn = makeSFTPConnection()
        XCTAssertTrue(conn.isSFTPConnection)
        XCTAssertFalse(conn.isS3Connection)
    }

    func testIsS3Connection() {
        let conn = makeS3Connection()
        XCTAssertTrue(conn.isS3Connection)
        XCTAssertFalse(conn.isSFTPConnection)
    }

    // MARK: - withUpdatedTimestamp

    func testWithUpdatedTimestamp() {
        let conn = makeSFTPConnection()
        let beforeDate = conn.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        let updated = conn.withUpdatedTimestamp()

        XCTAssertEqual(updated.id, conn.id)
        XCTAssertEqual(updated.name, conn.name)
        XCTAssertEqual(updated.host, conn.host)
        XCTAssertEqual(updated.port, conn.port)
        XCTAssertEqual(updated.username, conn.username)
        XCTAssertGreaterThan(updated.updatedAt, beforeDate)
    }

    // MARK: - Hashable

    func testHashable_SameID_SameFields_Equal() {
        let date = Date(timeIntervalSince1970: 1000)
        let id = UUID()
        let conn1 = Connection(id: id, name: "A", host: "a.com", username: "u1", createdAt: date, updatedAt: date)
        let conn2 = Connection(id: id, name: "A", host: "a.com", username: "u1", createdAt: date, updatedAt: date)
        XCTAssertEqual(conn1, conn2)
    }

    func testHashable_DifferentFields_NotEqual() {
        let id = UUID()
        let conn1 = Connection(id: id, name: "A", host: "a.com", username: "u1")
        let conn2 = Connection(id: id, name: "B", host: "b.com", username: "u2")
        XCTAssertNotEqual(conn1, conn2)
    }

    func testHashable_DifferentID_NotEqual() {
        let conn1 = Connection(id: UUID(), name: "A", host: "a.com", username: "u1")
        let conn2 = Connection(id: UUID(), name: "A", host: "a.com", username: "u1")
        XCTAssertNotEqual(conn1, conn2)
    }

    // MARK: - Codable

    func testCodable_RoundTrip() {
        let conn = Connection(
            name: "Test Server",
            host: "example.com",
            port: 2222,
            username: "admin",
            authMethod: .privateKey,
            privateKeyPath: "/home/user/.ssh/id_rsa",
            savePassword: true,
            description: "Production server",
            tags: ["prod", "web"],
            iconName: "server.rack",
            connectionType: .sftp,
            s3Region: nil,
            s3Bucket: nil,
            s3Endpoint: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try! encoder.encode(conn)
        let decoded = try! decoder.decode(Connection.self, from: data)

        XCTAssertEqual(decoded.id, conn.id)
        XCTAssertEqual(decoded.name, conn.name)
        XCTAssertEqual(decoded.host, conn.host)
        XCTAssertEqual(decoded.port, conn.port)
        XCTAssertEqual(decoded.username, conn.username)
        XCTAssertEqual(decoded.authMethod, conn.authMethod)
        XCTAssertEqual(decoded.privateKeyPath, conn.privateKeyPath)
        XCTAssertEqual(decoded.savePassword, conn.savePassword)
        XCTAssertEqual(decoded.description, conn.description)
        XCTAssertEqual(decoded.tags, conn.tags)
        XCTAssertEqual(decoded.iconName, conn.iconName)
        XCTAssertEqual(decoded.connectionType, conn.connectionType)
    }

    // MARK: - Helpers

    private func makeSFTPConnection(
        name: String = "Test",
        host: String = "example.com",
        port: Int = 22,
        username: String = "user",
        authMethod: AuthMethod = .password,
        privateKeyPath: String? = nil,
        tags: [String] = ["test"]
    ) -> Connection {
        Connection(
            name: name, host: host, port: port,
            username: username, authMethod: authMethod,
            privateKeyPath: privateKeyPath, tags: tags,
            connectionType: .sftp
        )
    }

    private func makeS3Connection(
        s3Bucket: String? = "my-bucket",
        s3Endpoint: String? = nil,
        s3Region: String? = "us-east-1"
    ) -> Connection {
        Connection(
            name: "S3 Test", host: "", username: "access",
            connectionType: .s3, s3Region: s3Region,
            s3Bucket: s3Bucket,
            s3Endpoint: s3Endpoint
        )
    }
}
