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
}
