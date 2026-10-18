//
//  SystemSFTPSessionTests.swift
//  macSCPTests
//
//  Unit tests for SystemSFTPSession security improvements
//

import XCTest
@testable import macSCP

final class SystemSFTPSessionTests: XCTestCase {

    // MARK: - Askpass Script Content

    func testAskpassScriptContent_ReadsFromEnvVar() {
        let content = SystemSFTPSession.askpassScriptContent
        XCTAssertTrue(content.contains("MACSCP_ASKPASS_PASS"),
                      "Script must read password from MACSCP_ASKPASS_PASS env var")
        XCTAssertTrue(content.hasPrefix("#!/bin/sh"),
                      "Script must be a valid shell script")
    }

    func testAskpassScriptContent_DoesNotContainEchoWithQuotes() {
        let content = SystemSFTPSession.askpassScriptContent
        XCTAssertFalse(content.contains("echo '"),
                       "Script must not embed password in echo command")
    }

    func testAskpassScriptContent_UsesPrintfNotEcho() {
        let content = SystemSFTPSession.askpassScriptContent
        XCTAssertTrue(content.contains("printf '%s'"),
                      "Script must use printf for safe output")
    }

    // MARK: - Askpass Script File Creation

    func testWriteAskpassScript_CreatesFileWithCorrectContent() async throws {
        let session = SystemSFTPSession()
        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("macSCP-test-askpass-\(UUID().uuidString).sh")

        try await session.writeAskpassScript(to: path)

        let fileContent = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertEqual(fileContent, SystemSFTPSession.askpassScriptContent)

        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let permissions = attrs[.posixPermissions] as? UInt16
        XCTAssertEqual(permissions, 0o700, "Script must have 0o700 permissions")

        try? FileManager.default.removeItem(atPath: path)
    }

    func testWriteAskpassScript_DoesNotContainPlaintextPassword() async throws {
        let session = SystemSFTPSession()
        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("macSCP-test-askpass-\(UUID().uuidString).sh")

        try await session.writeAskpassScript(to: path)

        let fileContent = try String(contentsOfFile: path, encoding: .utf8)
        let testPasswords = ["my$ecretP@ss!", "p@ss'with\"quotes", "pass\\nwith\\0null"]
        for password in testPasswords {
            XCTAssertFalse(fileContent.contains(password),
                           "Script file must not contain any plaintext password")
        }

        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Disconnect Cleanup

    func testDisconnect_ClearsPasswordState() async {
        let session = SystemSFTPSession()
        await session.disconnect()
        let connected = await session.isConnected
        XCTAssertFalse(connected)
    }

    func testDisconnect_CleansUpAskpassScriptFile() async throws {
        let session = SystemSFTPSession()
        let tempDir = NSTemporaryDirectory()
        let scriptPath = (tempDir as NSString).appendingPathComponent("macSCP-test-askpass-cleanup-\(UUID().uuidString).sh")

        try await session.writeAskpassScript(to: scriptPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptPath),
                       "Script file should exist after writeAskpassScript")

        try await session.setAskpassScriptPath(scriptPath)
        await session.disconnect()

        XCTAssertFalse(FileManager.default.fileExists(atPath: scriptPath),
                       "Script file should be deleted after disconnect")
    }

    // MARK: - Directory Listing

    /// Records the commands an injected transport was asked to run.
    private final class CommandLog: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String] = []

        func append(_ command: String) {
            lock.lock()
            storage.append(command)
            lock.unlock()
        }

        var commands: [String] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    func testListFiles_WhenListingFails_ThrowsWithPathInsteadOfEmptyDirectory() async {
        let log = CommandLog()
        let session = SystemSFTPSession(commandTransport: { command in
            log.append(command)
            throw AppError.sftpOperationFailed("exit code 2: Permission denied")
        })

        do {
            let files = try await session.listFiles(at: "/data/secret")
            XCTFail("Failed listing must throw, not report an empty directory (got \(files))")
        } catch let error as AppError {
            guard case .sftpOperationFailed(let message) = error else {
                XCTFail("Expected sftpOperationFailed, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("/data/secret"),
                          "Error must carry the offending path, got: \(message)")
        } catch {
            XCTFail("Expected AppError, got \(error)")
        }

        XCTAssertEqual(log.commands.count, 1)
        if let command = log.commands.first {
            XCTAssertFalse(command.contains("2>/dev/null"),
                           "Listing must not discard stderr; command was: \(command)")
        }
    }

    // MARK: - getFileInfo Path

    func testGetFileInfo_WhenLsEchoesFullPath_ReturnsRequestedPath() async throws {
        let session = SystemSFTPSession(commandTransport: { _ in
            "-rw-r--r-- 1 root wheel 4096 2024-01-15 14:30:45 /var/log/system.log"
        })

        let file = try await session.getFileInfo(at: "/var/log/system.log")

        XCTAssertEqual(file.path, "/var/log/system.log")
    }

    func testGetFileInfo_WhenLsEchoesBasename_ReturnsRequestedPath() async throws {
        let session = SystemSFTPSession(commandTransport: { _ in
            "-rw-r--r-- 1 root wheel 4096 2024-01-15 14:30:45 system.log"
        })

        let file = try await session.getFileInfo(at: "/var/log/system.log")

        XCTAssertEqual(file.path, "/var/log/system.log")
    }

    func testGetFileInfo_ParsesBsdFormattedLine() async throws {
        let session = SystemSFTPSession(commandTransport: { _ in
            "-rw-r--r--  1 root  wheel  4096 Jan 15 14:30 /var/log/system.log"
        })

        let file = try await session.getFileInfo(at: "/var/log/system.log")

        XCTAssertEqual(file.path, "/var/log/system.log")
        XCTAssertFalse(file.isDirectory)
    }
}
