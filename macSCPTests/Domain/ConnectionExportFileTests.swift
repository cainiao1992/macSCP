//
//  ConnectionExportFileTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionExportFile + ConnectionExportCodec (Phase 6).
//  Proves the core security properties: no secrets in JSON, round-trip
//  preserves all fields, version + iso8601 dates, injected keys ignored.
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionExportFileTests: XCTestCase {

    // MARK: - Helpers

    private func makeSFTPConnection(
        name: String = "prod-server",
        host: String = "10.0.0.1",
        port: Int = 22,
        username: String = "alice"
    ) -> Connection {
        Connection(
            name: name,
            host: host,
            port: port,
            username: username,
            authMethod: .privateKey,
            privateKeyPath: "/Users/alice/.ssh/id_ed25519",
            savePassword: true,
            description: "Production web server",
            tags: ["prod", "web"],
            iconName: "server.rack",
            folderId: UUID(),
            connectionType: .sftp,
            isFavorite: true
        )
    }

    private func makeS3Connection(
        name: String = "backup-bucket",
        username: String = "AKIAIOSFODNN7EXAMPLE"
    ) -> Connection {
        Connection(
            name: name,
            host: "",
            port: 0,
            username: username,
            connectionType: .s3,
            s3Region: "us-east-1",
            s3Bucket: "my-backup-bucket",
            s3Endpoint: "https://s3.example.com",
            isFavorite: false
        )
    }

    private func makeSampleFile() -> ConnectionExportFile {
        ConnectionExportFile(
            version: ConnectionExportFile.currentVersion,
            exportedAt: Date(timeIntervalSince1970: 1_784_747_869), // 2026-07-22T...
            appVersion: "1.3.0",
            connections: [makeSFTPConnection(), makeS3Connection()],
            folders: [Folder(name: "Servers", displayOrder: 0)]
        )
    }

    // MARK: - EXP-01: No secrets in exported JSON (T-6-01)

    func testExport_containsNoSecretFields() throws {
        // Arrange
        let file = makeSampleFile()

        // Act
        let data = try ConnectionExportCodec.encoder().encode(file)
        let jsonString = String(data: data, encoding: .utf8) ?? ""

        // Assert — no secret-carrying KEYS present in the output.
        // We check the key form `"key" :` (key followed by colon). Note:
        // `authMethod : "password"` is a legitimate ENUM VALUE (auth method
        // indicator), NOT a credential — the value form `: "password"` is
        // allowed. A secret field would render as `"password" : "<value>"`.
        XCTAssertFalse(
            jsonString.contains("\"password\" :"),
            "JSON must not contain a 'password' KEY (credential field)"
        )
        XCTAssertFalse(
            jsonString.contains("\"s3SecretAccessKey\" :"),
            "JSON must not contain an 's3SecretAccessKey' KEY"
        )
        XCTAssertFalse(
            jsonString.contains("\"secret"),
            "JSON must not contain any 'secret'-named key"
        )

        // Positive control — configuration fields ARE present
        XCTAssertTrue(jsonString.contains("\"host\""), "JSON must contain host field")
        XCTAssertTrue(jsonString.contains("\"username\""), "JSON must contain username field")
        XCTAssertTrue(jsonString.contains("\"port\""), "JSON must contain port field")
    }

    // MARK: - Round-trip preserves all Connection fields

    func testRoundTrip_preservesAllFields() throws {
        // Arrange
        let original = makeSampleFile()
        let originalSFTP = original.connections[0]

        // Act
        let data = try ConnectionExportCodec.encoder().encode(original)
        let decoded = try ConnectionExportCodec.decoder().decode(
            ConnectionExportFile.self,
            from: data
        )

        // Assert — envelope
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.appVersion, original.appVersion)
        XCTAssertEqual(decoded.connections.count, 2)
        XCTAssertEqual(decoded.folders.count, 1)

        // Assert — SFTP connection ALL stored properties preserved (WR-02)
        let decodedSFTP = decoded.connections[0]
        XCTAssertEqual(decodedSFTP.id, originalSFTP.id)
        XCTAssertEqual(decodedSFTP.name, originalSFTP.name)
        XCTAssertEqual(decodedSFTP.host, originalSFTP.host)
        XCTAssertEqual(decodedSFTP.port, originalSFTP.port)
        XCTAssertEqual(decodedSFTP.username, originalSFTP.username)
        XCTAssertEqual(decodedSFTP.connectionType, originalSFTP.connectionType)
        XCTAssertEqual(decodedSFTP.folderId, originalSFTP.folderId)
        XCTAssertEqual(decodedSFTP.isFavorite, originalSFTP.isFavorite)
        XCTAssertEqual(decodedSFTP.privateKeyPath, originalSFTP.privateKeyPath)
        XCTAssertEqual(decodedSFTP.authMethod, originalSFTP.authMethod)
        XCTAssertEqual(decodedSFTP.savePassword, originalSFTP.savePassword)
        XCTAssertEqual(decodedSFTP.description, originalSFTP.description)
        XCTAssertEqual(decodedSFTP.tags, originalSFTP.tags)
        XCTAssertEqual(decodedSFTP.iconName, originalSFTP.iconName)
        // ISO8601 date strategy truncates sub-second precision, so compare
        // at whole-second granularity (same as exportedAt below).
        XCTAssertEqual(Int(decodedSFTP.createdAt.timeIntervalSince1970), Int(originalSFTP.createdAt.timeIntervalSince1970), "createdAt preserved (second precision)")
        XCTAssertEqual(Int(decodedSFTP.updatedAt.timeIntervalSince1970), Int(originalSFTP.updatedAt.timeIntervalSince1970), "updatedAt preserved (second precision)")
        XCTAssertEqual(decodedSFTP.lastUsedAt, originalSFTP.lastUsedAt)

        // Assert — S3 connection ALL stored properties preserved (WR-02)
        let originalS3 = original.connections[1]
        let decodedS3 = decoded.connections[1]
        XCTAssertEqual(decodedS3.id, originalS3.id)
        XCTAssertEqual(decodedS3.name, originalS3.name)
        XCTAssertEqual(decodedS3.username, originalS3.username)
        XCTAssertEqual(decodedS3.connectionType, originalS3.connectionType)
        XCTAssertEqual(decodedS3.s3Region, originalS3.s3Region)
        XCTAssertEqual(decodedS3.s3Bucket, originalS3.s3Bucket)
        XCTAssertEqual(decodedS3.s3Endpoint, originalS3.s3Endpoint)
        XCTAssertEqual(decodedS3.isFavorite, originalS3.isFavorite)

        // Assert — envelope exportedAt preserved (WR-02)
        XCTAssertEqual(decoded.exportedAt, original.exportedAt)

        // Assert — folder fields preserved (WR-02)
        let decodedFolder = decoded.folders[0]
        XCTAssertEqual(decodedFolder.name, original.folders[0].name)
        XCTAssertEqual(decodedFolder.displayOrder, original.folders[0].displayOrder)
    }

    // MARK: - Version field + iso8601 date strategy

    func testExport_hasVersionAndIsoDate() throws {
        // Arrange
        let file = makeSampleFile()

        // Act
        let data = try ConnectionExportCodec.encoder().encode(file)
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        let decoded = try ConnectionExportCodec.decoder().decode(
            ConnectionExportFile.self,
            from: data
        )

        // Assert — version round-trips
        XCTAssertEqual(decoded.version, ConnectionExportFile.currentVersion)

        // Assert — date uses iso8601 (contains 'T' and 'Z'), NOT a bare Double
        XCTAssertTrue(
            jsonString.contains("\"exportedAt\""),
            "JSON must contain exportedAt field"
        )
        XCTAssertTrue(
            jsonString.contains("T") && jsonString.contains("Z"),
            "Date must be ISO-8601 (contains T and Z), not a raw Double"
        )
    }

    // MARK: - IMP-04 / T-6-02: Decoder ignores injected keys (tampering)

    func testDecode_ignoresUnknownKeys_injectedPassword() throws {
        // Arrange — start from a legitimate export, then inject secret keys
        let file = makeSampleFile()
        let data = try ConnectionExportCodec.encoder().encode(file)
        var jsonString = String(data: data, encoding: .utf8) ?? ""

        // Inject malicious keys INSIDE the first connection object (after its
        // opening brace). Synthesized Codable must silently drop these — T-6-02.
        // JSON is whitespace-agnostic, so the injected key/value pairs are valid.
        let injection = "\"injectedPassword\": \"LEAKED_SECRET\", \"s3SecretAccessKey\": \"LEAKED_KEY\","
        if let connectionsRange = jsonString.range(of: "\"connections\"") {
            let afterConnections = jsonString[connectionsRange.upperBound...]
            if let braceRange = afterConnections.range(of: "{") {
                jsonString.insert(contentsOf: " " + injection, at: braceRange.upperBound)
            }
        }

        let tamperedData = Data(jsonString.utf8)

        // Act — decode must succeed (no crash) and ignore the injected keys
        let decoded = try ConnectionExportCodec.decoder().decode(
            ConnectionExportFile.self,
            from: tamperedData
        )

        // Assert — decode succeeded, first connection is a valid Connection
        XCTAssertEqual(decoded.connections.count, 2)
        let first = decoded.connections[0]
        XCTAssertEqual(first.name, file.connections[0].name)
        XCTAssertEqual(first.host, file.connections[0].host)

        // Connection has no password property to read back — the injection is
        // structurally gone. Proven by the absence of any secret accessor.
    }
}
