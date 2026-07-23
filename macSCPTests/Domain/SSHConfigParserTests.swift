//
//  SSHConfigParserTests.swift
//  macSCPTests
//
//  Unit tests for the SSH config parser
//

import XCTest
@testable import macSCP

@MainActor
final class SSHConfigParserTests: XCTestCase {

    // MARK: - Properties

    private var parser: SSHConfigParser!
    private var tempDir: URL!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        parser = SSHConfigParser()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHConfigParserTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        parser = nil
        tempDir = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeTempFile(name: String, content: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Basic Parsing

    func testParse_singleHostBlock_parsesAllFields() {
        // Arrange
        let config = """
        Host myserver
            HostName 192.168.1.100
            Port 2222
            User admin
            IdentityFile ~/.ssh/id_rsa
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        let entry = result.entries[0]
        XCTAssertEqual(entry.host, "myserver")
        XCTAssertEqual(entry.hostName, "192.168.1.100")
        XCTAssertEqual(entry.port, 2222)
        XCTAssertEqual(entry.user, "admin")
        XCTAssertEqual(entry.identityFile, (("~/.ssh/id_rsa") as NSString).expandingTildeInPath)
        XCTAssertEqual(result.wildcardCount, 0)
        XCTAssertTrue(result.includeWarnings.isEmpty)
    }

    func testParse_multipleHostBlocks_producesSeparateEntries() {
        // Arrange
        let config = """
        Host server1
            HostName 10.0.0.1
            Port 22
            User alice

        Host server2
            HostName 10.0.0.2
            Port 2222
            User bob
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.entries[0].hostName, "10.0.0.1")
        XCTAssertEqual(result.entries[0].port, 22)
        XCTAssertEqual(result.entries[0].user, "alice")
        XCTAssertEqual(result.entries[1].host, "server2")
        XCTAssertEqual(result.entries[1].hostName, "10.0.0.2")
        XCTAssertEqual(result.entries[1].port, 2222)
        XCTAssertEqual(result.entries[1].user, "bob")
    }

    func testParse_missingOptionalFields_producesNilValues() {
        // Arrange
        let config = """
        Host minimal
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        let entry = result.entries[0]
        XCTAssertEqual(entry.host, "minimal")
        XCTAssertNil(entry.hostName)
        XCTAssertEqual(entry.port, 22)
        XCTAssertNil(entry.user)
        XCTAssertNil(entry.identityFile)
    }

    func testParse_emptyContent_producesEmptyResult() {
        // Arrange
        let config = ""

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.wildcardCount, 0)
        XCTAssertTrue(result.includeWarnings.isEmpty)
    }

    func testParse_whitespaceOnlyContent_producesEmptyResult() {
        // Arrange
        let config = "   \n\n  \n  "

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertTrue(result.entries.isEmpty)
    }

    // MARK: - Wildcard Handling

    func testParse_wildcardHost_skippedAndCounted() {
        // Arrange
        let config = """
        Host *
            ServerAliveInterval 60

        Host ?foo
            HostName bar.com

        Host *.example.com
            User webadmin
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.wildcardCount, 3)
    }

    func testParse_multiTokenHost_producesOneEntryPerToken() {
        // Arrange
        let config = """
        Host server1 server2 server3
            HostName shared.example.com
            Port 22
            User shared
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 3)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.entries[1].host, "server2")
        XCTAssertEqual(result.entries[2].host, "server3")
        for entry in result.entries {
            XCTAssertEqual(entry.hostName, "shared.example.com")
            XCTAssertEqual(entry.port, 22)
            XCTAssertEqual(entry.user, "shared")
        }
    }

    func testParse_mixedWildcardAndNonWildcard() {
        // Arrange
        let config = """
        Host server1 *.staging
            HostName example.com
            User deploy
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.wildcardCount, 1)
    }

    func testParse_onlyWildcardHosts_emptyEntriesWithCount() {
        // Arrange
        let config = """
        Host *
            ServerAliveInterval 60
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.wildcardCount, 1)
    }

    // MARK: - Comments and Blank Lines

    func testParse_commentsAndBlankLines_ignored() {
        // Arrange
        let config = """
        # This is a comment
        Host server1
            # Another comment
            HostName 10.0.0.1

            User alice
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.entries[0].hostName, "10.0.0.1")
        XCTAssertEqual(result.entries[0].user, "alice")
    }

    // MARK: - Case Insensitivity

    func testParse_caseInsensitiveDirectives() {
        // Arrange
        let config = """
        host server1
            hostname 10.0.0.1
            port 2222
            user alice
            identityfile ~/.ssh/key

        HOST server2
            HOSTNAME 10.0.0.2
            PORT 3333
            USER bob
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.entries[0].hostName, "10.0.0.1")
        XCTAssertEqual(result.entries[0].port, 2222)
        XCTAssertEqual(result.entries[1].host, "server2")
        XCTAssertEqual(result.entries[1].hostName, "10.0.0.2")
        XCTAssertEqual(result.entries[1].port, 3333)
    }

    // MARK: - Key=Value Syntax

    func testParse_keyValueSyntax() {
        // Arrange
        let config = """
        Host=server1
            HostName=10.0.0.1
            Port=2222
            User=alice
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertEqual(result.entries[0].hostName, "10.0.0.1")
        XCTAssertEqual(result.entries[0].port, 2222)
        XCTAssertEqual(result.entries[0].user, "alice")
    }

    // MARK: - Port Validation

    func testParse_portOutOfRange_fallsBackTo22() {
        // Arrange
        let config1 = """
        Host server1
            Port 0
        """
        let config2 = """
        Host server2
            Port -1
        """
        let config3 = """
        Host server3
            Port 99999
        """

        // Act
        let result1 = parser.parse(content: config1)
        let result2 = parser.parse(content: config2)
        let result3 = parser.parse(content: config3)

        // Assert
        XCTAssertEqual(result1.entries[0].port, 22)
        XCTAssertEqual(result2.entries[0].port, 22)
        XCTAssertEqual(result3.entries[0].port, 22)
    }

    func testParse_portValidBoundary() {
        // Arrange
        let config = """
        Host server1
            Port 1

        Host server2
            Port 65535
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries[0].port, 1)
        XCTAssertEqual(result.entries[1].port, 65535)
    }

    // MARK: - Duplicate Keys

    func testParse_duplicateKeys_lastValueWins() {
        // Arrange
        let config = """
        Host server1
            HostName first.com
            HostName second.com
            User alice
            User bob
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].hostName, "second.com")
        XCTAssertEqual(result.entries[0].user, "bob")
    }

    // MARK: - File I/O

    func testParseFileURL_nonExistentURL_throwsImportFailed() {
        // Arrange
        let url = URL(fileURLWithPath: "/tmp/non-existent-ssh-config-\(UUID().uuidString)")

        // Act & Assert
        XCTAssertThrowsError(try parser.parse(fileURL: url)) { error in
            guard case AppError.importFailed = error else {
                XCTFail("Expected AppError.importFailed, got \(error)")
                return
            }
        }
    }

    func testParseFileURL_validFile_parsesEntries() {
        // Arrange
        let config = """
        Host testserver
            HostName 10.0.0.1
            Port 2222
            User tester
        """
        let fileURL = writeTempFile(name: "config", content: config)

        // Act
        let result = try? parser.parse(fileURL: fileURL)

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entries.count, 1)
        XCTAssertEqual(result?.entries[0].host, "testserver")
    }

    // MARK: - Include Directive

    func testParse_includeDirective_validFile() {
        // Arrange
        let includedConfig = """
        Host included-server
            HostName 10.0.0.5
            Port 22
            User included
        """
        let includedFile = writeTempFile(name: "included_config", content: includedConfig)

        let mainConfig = """
        Host main-server
            HostName 10.0.0.1
            User main

        Include \(includedFile.path)
        """

        // Act
        let result = parser.parse(content: mainConfig, baseURL: tempDir)

        // Assert
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].host, "main-server")
        XCTAssertEqual(result.entries[1].host, "included-server")
        XCTAssertEqual(result.entries[1].hostName, "10.0.0.5")
    }

    func testParse_includeDirective_nonExistentFile_addsWarning() {
        // Arrange
        let config = """
        Host server1
            HostName 10.0.0.1

        Include /tmp/non-existent-config-\(UUID().uuidString)
        """

        // Act
        let result = parser.parse(content: config, baseURL: tempDir)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].host, "server1")
        XCTAssertFalse(result.includeWarnings.isEmpty)
    }

    func testParse_includeDirective_relativePath() {
        // Arrange
        let includedConfig = """
        Host relative-server
            HostName 10.0.0.9
        """
        let subDir = tempDir.appendingPathComponent("config.d")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let includedURL = subDir.appendingPathComponent("extra.conf")
        try? includedConfig.write(to: includedURL, atomically: true, encoding: .utf8)

        let mainConfig = """
        Include config.d/extra.conf
        """

        // Act
        let result = parser.parse(content: mainConfig, baseURL: tempDir)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].host, "relative-server")
    }

    func testParse_includeDirective_tildeExpansion() {
        // Arrange: create a file in a known location and use its absolute path
        // (testing tilde expansion directly would require creating files in ~, which is unsafe)
        // Instead, verify the expandPath mechanism works by checking the parser handles it
        let config = """
        Host server1
            HostName 10.0.0.1

        Include ~/non-existent-test-file-\(UUID().uuidString)
        """

        // Act
        let result = parser.parse(content: config, baseURL: tempDir)

        // Assert — include warning because file doesn't exist, but no crash
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertFalse(result.includeWarnings.isEmpty)
    }

    func testParse_nestedInclude_resolvesCorrectly() {
        // Arrange
        let configC = """
        Host serverC
            HostName 10.0.0.3
        """
        let fileC = writeTempFile(name: "config_c", content: configC)

        let configB = """
        Host serverB
            HostName 10.0.0.2

        Include \(fileC.path)
        """
        let fileB = writeTempFile(name: "config_b", content: configB)

        let configA = """
        Host serverA
            HostName 10.0.0.1

        Include \(fileB.path)
        """

        // Act
        let result = parser.parse(content: configA, baseURL: tempDir)

        // Assert
        XCTAssertEqual(result.entries.count, 3)
        let hosts = result.entries.map(\.host)
        XCTAssertTrue(hosts.contains("serverA"))
        XCTAssertTrue(hosts.contains("serverB"))
        XCTAssertTrue(hosts.contains("serverC"))
    }

    func testParse_circularInclude_doesNotInfiniteLoop() {
        // Arrange — create two files that include each other
        let fileAPath = tempDir.appendingPathComponent("config_a").path
        let fileBPath = tempDir.appendingPathComponent("config_b_circular").path

        let configA = """
        Host serverA
            HostName 10.0.0.1

        Include \(fileBPath)
        """

        let configB = """
        Host serverB
            HostName 10.0.0.2

        Include \(fileAPath)
        """

        try? configA.write(toFile: fileAPath, atomically: true, encoding: .utf8)
        try? configB.write(toFile: fileBPath, atomically: true, encoding: .utf8)

        // Act
        let result = parser.parse(content: configA, baseURL: tempDir)

        // Assert — should complete without infinite loop
        XCTAssertGreaterThanOrEqual(result.entries.count, 1)
        // The circular include should be silently skipped
    }

    // MARK: - Include with Glob Patterns

    func testParse_includeDirective_globPattern() {
        // Arrange
        let subDir = tempDir.appendingPathComponent("conf.d")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let config1 = """
        Host glob-server1
            HostName 10.0.0.10
        """
        let config2 = """
        Host glob-server2
            HostName 10.0.0.11
        """
        try? config1.write(to: subDir.appendingPathComponent("01-server1.conf"), atomically: true, encoding: .utf8)
        try? config2.write(to: subDir.appendingPathComponent("02-server2.conf"), atomically: true, encoding: .utf8)

        let mainConfig = """
        Include \(subDir.path)/*.conf
        """

        // Act
        let result = parser.parse(content: mainConfig, baseURL: tempDir)

        // Assert
        XCTAssertEqual(result.entries.count, 2)
        let hosts = result.entries.map(\.host).sorted()
        XCTAssertTrue(hosts.contains("glob-server1"))
        XCTAssertTrue(hosts.contains("glob-server2"))
    }

    // MARK: - IdentityFile Path Expansion

    func testParse_identityFile_expandsTilde() {
        // Arrange
        let config = """
        Host server1
            IdentityFile ~/.ssh/custom_key
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries.count, 1)
        let expectedPath = ("~/.ssh/custom_key" as NSString).expandingTildeInPath
        XCTAssertEqual(result.entries[0].identityFile, expectedPath)
    }

    func testParse_identityFile_absolutePathUnchanged() {
        // Arrange
        let config = """
        Host server1
            IdentityFile /Users/test/.ssh/id_ed25519
        """

        // Act
        let result = parser.parse(content: config)

        // Assert
        XCTAssertEqual(result.entries[0].identityFile, "/Users/test/.ssh/id_ed25519")
    }
}
