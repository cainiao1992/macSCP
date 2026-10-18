//
//  FileOperationsCoordinatorTests.swift
//  macSCPTests
//
//  Unit tests for FileOperationsCoordinator — proves independent testability (VM-SPLIT-03)
//

import XCTest
@testable import macSCP

@MainActor
final class FileOperationsCoordinatorTests: XCTestCase {
    var sut: FileOperationsCoordinator!
    var mockFileRepository: MockFileRepository!
    var mockClipboardService: MockClipboardService!

    let testConnection = Connection(
        name: "Test Server",
        host: "test.example.com",
        username: "testuser"
    )

    var filesChangedCalled = false
    var capturedError: AppError?

    override func setUp() async throws {
        try await super.setUp()
        mockFileRepository = MockFileRepository()
        await mockFileRepository.reset()
        mockClipboardService = MockClipboardService()
        await mockClipboardService.reset()
        filesChangedCalled = false
        capturedError = nil

        sut = FileOperationsCoordinator(
            fileRepository: mockFileRepository,
            clipboardService: mockClipboardService,
            connection: testConnection,
            onFilesChanged: { [weak self] in self?.filesChangedCalled = true },
            onError: { [weak self] error in self?.capturedError = error },
            getCurrentPath: { "/home/user" },
            getSelectedFilesList: { [] }
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFileRepository = nil
        mockClipboardService = nil
        try await super.tearDown()
    }

    // MARK: - Independent Instantiation (VM-SPLIT-03)

    func testFileOperationsCoordinator_CanBeInstantiatedWithMockDeps() {
        XCTAssertNotNil(sut)
    }

    // MARK: - createFolder

    func testCreateFolder_CallsFileRepositoryAndOnFilesChanged() async {
        let result = await sut.createFolder(name: "NewFolder")

        XCTAssertTrue(result)
        XCTAssertTrue(mockFileRepository.createDirectoryCalled)
        XCTAssertEqual(mockFileRepository.lastCreateDirectoryPath, "/home/user/NewFolder")
        XCTAssertTrue(filesChangedCalled)
    }

    func testCreateFolder_ReturnsFalseOnError() async {
        await mockFileRepository.reset()
        mockFileRepository.mockError = AppError.sftpOperationFailed("Permission denied")

        let result = await sut.createFolder(name: "BadFolder")

        XCTAssertFalse(result)
        XCTAssertNotNil(capturedError)
        XCTAssertFalse(filesChangedCalled)
    }

    // MARK: - renameFile

    func testRenameFile_CallsFileRepositoryRename() async {
        let file = RemoteFile(name: "old.txt", path: "/home/user/old.txt", isDirectory: false, size: 100, permissions: "-rw-r--r--")
        let result = await sut.renameFile(file, to: "new.txt")

        XCTAssertTrue(result)
        XCTAssertTrue(mockFileRepository.renameCalled)
        XCTAssertEqual(mockFileRepository.lastRenameSourcePath, "/home/user/old.txt")
        XCTAssertEqual(mockFileRepository.lastRenameDestPath, "/home/user/new.txt")
    }

    // MARK: - deleteFiles

    func testDeleteFiles_CallsFileRepositoryDeleteForEachFile() async {
        let files = [
            RemoteFile(name: "a.txt", path: "/home/user/a.txt", isDirectory: false, size: 100, permissions: "-rw-r--r--"),
            RemoteFile(name: "b.txt", path: "/home/user/b.txt", isDirectory: false, size: 200, permissions: "-rw-r--r--")
        ]
        let result = await sut.deleteFiles(files)

        XCTAssertTrue(result)
        XCTAssertTrue(mockFileRepository.deleteCalled)
    }

    // MARK: - copySelectedFiles

    func testCopySelectedFiles_CallsClipboardServiceCopy() {
        let file = RemoteFile(name: "test.txt", path: "/home/user/test.txt", isDirectory: false, size: 100, permissions: "-rw-r--r--")

        // Use a separate coordinator instance with selected files.
        // We avoid reassigning sut because the @MainActor back-deploy deinit path
        // can trigger a memory-corruption crash (SIGABRT) during old-instance deallocation.
        let coordinator = FileOperationsCoordinator(
            fileRepository: mockFileRepository,
            clipboardService: mockClipboardService,
            connection: testConnection,
            onFilesChanged: {},
            onError: { _ in },
            getCurrentPath: { "/home/user" },
            getSelectedFilesList: { [file] }
        )

        coordinator.copySelectedFiles()

        XCTAssertTrue(mockClipboardService.copyCalled)
        XCTAssertEqual(mockClipboardService.lastCopiedFiles?.count, 1)
        XCTAssertEqual(mockClipboardService.lastCopiedSourcePath, "/home/user")
    }
}
