//
//  WindowActionCoordinatorTests.swift
//  macSCPTests
//
//  Unit tests for WindowActionCoordinator — proves independent testability of the
//  secondary-window opening logic extracted in Phase 10 (Plan 03).
//

import XCTest
@testable import macSCP

@MainActor
final class WindowActionCoordinatorTests: XCTestCase {
    var sut: WindowActionCoordinator!
    var mockWindowManager: MockWindowManager!

    let sftpConnection = Connection(
        name: "SFTP Server",
        host: "sftp.example.com",
        username: "user",
        connectionType: .sftp
    )

    let s3Connection = Connection(
        name: "S3 Bucket",
        host: "s3.example.com",
        username: "user",
        connectionType: .s3,
        s3Region: "us-east-1",
        s3Bucket: "my-bucket"
    )

    let testFile = RemoteFile(
        name: "notes.txt",
        path: "/home/user/notes.txt",
        isDirectory: false,
        size: 42,
        permissions: "-rw-r--r--"
    )

    override func setUp() async throws {
        try await super.setUp()
        mockWindowManager = MockWindowManager()
        sut = WindowActionCoordinator(
            connection: sftpConnection,
            password: "secret",
            windowManager: mockWindowManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockWindowManager = nil
        try await super.tearDown()
    }

    // MARK: - Independent Instantiation

    func testCanBeInstantiatedWithMockDeps() {
        XCTAssertNotNil(sut)
    }

    // MARK: - File Info

    func testFileInfoWindowId_StoresDataAndReturnsId() {
        let id = sut.fileInfoWindowId(for: testFile)

        XCTAssertFalse(id.isEmpty)
        XCTAssertTrue(mockWindowManager.storeFileInfoDataCalled)
        let stored = mockWindowManager.getFileInfoData(for: id)
        XCTAssertEqual(stored?.file.path, testFile.path)
        XCTAssertEqual(stored?.connectionName, "SFTP Server")
    }

    // MARK: - Editor

    func testEditorWindowId_StoresDataWithContent() {
        let id = sut.editorWindowId(for: testFile, content: "hello")

        XCTAssertFalse(id.isEmpty)
        XCTAssertTrue(mockWindowManager.storeFileEditorDataCalled)
        let stored = mockWindowManager.getFileEditorData(for: id)
        XCTAssertEqual(stored?.filePath, testFile.path)
        XCTAssertEqual(stored?.content, "hello")
        XCTAssertEqual(stored?.password, "secret")
        XCTAssertEqual(stored?.connectionType, .sftp)
    }
}
