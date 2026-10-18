//
//  ConnectionLifecycleCoordinatorTests.swift
//  macSCPTests
//
//  Unit tests for ConnectionLifecycleCoordinator — proves the connect path
//  returns a ConnectionOutcome the VM applies, with no VM state mutated inside
//  the coordinator (VM-SPLIT-01, connection lifecycle extraction).
//

import XCTest
@testable import macSCP

@MainActor
final class ConnectionLifecycleCoordinatorTests: XCTestCase {
    var sut: ConnectionLifecycleCoordinator!
    var mockSFTPSession: MockSFTPSession!

    let testConnection = Connection(
        name: "Test Server",
        host: "test.example.com",
        username: "testuser"
    )

    override func setUp() async throws {
        try await super.setUp()
        mockSFTPSession = MockSFTPSession()
        await mockSFTPSession.reset()

        sut = ConnectionLifecycleCoordinator(
            connection: testConnection,
            sftpSession: mockSFTPSession,
            s3Session: nil,
            password: "testpass"
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSFTPSession = nil
        try await super.tearDown()
    }

    // MARK: - connect() → .connected

    func testConnect_SFTP_Success_ReturnsConnectedOutcome() async {
        // Arrange — MockSFTPSession reports mockRealPath after connect.
        await mockSFTPSession.reset()

        // Act
        let outcome = await sut.connect()

        // Assert — coordinator delegates to the session and returns the resolved path.
        let connectCalled = await mockSFTPSession.connectPasswordCalled
        XCTAssertTrue(connectCalled)
        if case .connected(let path) = outcome {
            XCTAssertEqual(path, "/home/user")
        } else {
            XCTFail("Expected .connected, got \(outcome)")
        }
    }

    // MARK: - connect() → .hostKeyMismatch

    func testConnect_HostKeyMismatch_ReturnsHostKeyMismatchOutcome() async {
        // Arrange
        await mockSFTPSession.reset()
        await mockSFTPSession.setMockError(
            AppError.hostKeyMismatch(host: "test.example.com", port: 22)
        )

        // Act
        let outcome = await sut.connect()

        // Assert — coordinator extracts host/port from the mapped AppError, no VM state touched.
        if case .hostKeyMismatch(let host, let port) = outcome {
            XCTAssertEqual(host, "test.example.com")
            XCTAssertEqual(port, 22)
        } else {
            XCTFail("Expected .hostKeyMismatch, got \(outcome)")
        }
    }

    // MARK: - connect() → .error

    func testConnect_GenericError_ReturnsErrorOutcome() async {
        // Arrange
        await mockSFTPSession.reset()
        await mockSFTPSession.setMockError(AppError.connectionFailed("timeout"))

        // Act
        let outcome = await sut.connect()

        // Assert — all non-host-key failures are wrapped via AppError.from.
        if case .error(let appError) = outcome {
            if case .connectionFailed = appError {
            } else {
                XCTFail("Expected .connectionFailed, got \(appError)")
            }
        } else {
            XCTFail("Expected .error, got \(outcome)")
        }
    }
}
