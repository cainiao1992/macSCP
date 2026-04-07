//
//  WindowManagerTests.swift
//  macSCPTests
//
//  Unit tests for WindowManager multi-window data passing
//

import XCTest
@testable import macSCP

@MainActor
final class WindowManagerTests: XCTestCase {
    let manager = WindowManager.shared

    // MARK: - Helpers

    private func makeBrowserData() -> FileBrowserWindowData {
        FileBrowserWindowData(
            connectionId: UUID(),
            connectionName: "Test Browser",
            host: "browser.example.com",
            port: 22,
            username: "browseruser",
            password: "browserpass",
            authMethod: .password,
            privateKeyPath: nil
        )
    }

    private func makeEditorData() -> FileEditorWindowData {
        FileEditorWindowData(
            filePath: "/remote/path/file.txt",
            fileName: "file.txt",
            content: "Hello, World!",
            connectionId: UUID(),
            host: "editor.example.com",
            port: 22,
            username: "editoruser",
            password: "editorpass",
            authMethod: .password,
            privateKeyPath: nil
        )
    }

    private func makeFileInfoData() -> FileInfoWindowData {
        FileInfoWindowData(
            file: RemoteFile(
                name: "test.txt",
                path: "/remote/test.txt",
                isDirectory: false,
                size: 1024,
                permissions: "rw-r--r--",
                modificationDate: Date()
            ),
            connectionName: "Test Connection"
        )
    }

    private func makeTerminalData() -> TerminalWindowData {
        TerminalWindowData(
            connectionId: UUID(),
            connectionName: "Test Terminal",
            host: "term.example.com",
            port: 22,
            username: "termuser",
            password: "termpass",
            authMethod: .password,
            privateKeyPath: nil
        )
    }

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        manager.clearAllData()
    }

    override func tearDown() async throws {
        manager.clearAllData()
        try await super.tearDown()
    }

    // MARK: - FileBrowserWindowData CRUD

    func testStoreFileBrowserData_ReturnsNonEmptyID() {
        let id = manager.storeFileBrowserData(makeBrowserData())
        XCTAssertFalse(id.isEmpty)
    }

    func testGetFileBrowserData_ReturnsStoredData() {
        let data = makeBrowserData()
        let id = manager.storeFileBrowserData(data)

        let retrieved = manager.getFileBrowserData(for: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.connectionName, "Test Browser")
        XCTAssertEqual(retrieved?.host, "browser.example.com")
        XCTAssertEqual(retrieved?.username, "browseruser")
    }

    func testGetFileBrowserData_NonexistentID_ReturnsNil() {
        let result = manager.getFileBrowserData(for: "nonexistent")
        XCTAssertNil(result)
    }

    func testRemoveFileBrowserData_SubsequentGetReturnsNil() {
        let id = manager.storeFileBrowserData(makeBrowserData())
        XCTAssertNotNil(manager.getFileBrowserData(for: id))

        manager.removeFileBrowserData(for: id)

        XCTAssertNil(manager.getFileBrowserData(for: id))
    }

    // MARK: - FileEditorWindowData CRUD

    func testStoreFileEditorData_ReturnsNonEmptyID() {
        let id = manager.storeFileEditorData(makeEditorData())
        XCTAssertFalse(id.isEmpty)
    }

    func testGetFileEditorData_ReturnsStoredData() {
        let data = makeEditorData()
        let id = manager.storeFileEditorData(data)

        let retrieved = manager.getFileEditorData(for: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.fileName, "file.txt")
        XCTAssertEqual(retrieved?.filePath, "/remote/path/file.txt")
        XCTAssertEqual(retrieved?.content, "Hello, World!")
    }

    func testGetFileEditorData_NonexistentID_ReturnsNil() {
        let result = manager.getFileEditorData(for: "nonexistent")
        XCTAssertNil(result)
    }

    func testRemoveFileEditorData_SubsequentGetReturnsNil() {
        let id = manager.storeFileEditorData(makeEditorData())
        XCTAssertNotNil(manager.getFileEditorData(for: id))

        manager.removeFileEditorData(for: id)

        XCTAssertNil(manager.getFileEditorData(for: id))
    }

    // MARK: - FileInfoWindowData CRUD

    func testStoreFileInfoData_ReturnsNonEmptyID() {
        let id = manager.storeFileInfoData(makeFileInfoData())
        XCTAssertFalse(id.isEmpty)
    }

    func testGetFileInfoData_ReturnsStoredData() {
        let data = makeFileInfoData()
        let id = manager.storeFileInfoData(data)

        let retrieved = manager.getFileInfoData(for: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.connectionName, "Test Connection")
        XCTAssertEqual(retrieved?.file.name, "test.txt")
    }

    func testGetFileInfoData_NonexistentID_ReturnsNil() {
        let result = manager.getFileInfoData(for: "nonexistent")
        XCTAssertNil(result)
    }

    func testRemoveFileInfoData_SubsequentGetReturnsNil() {
        let id = manager.storeFileInfoData(makeFileInfoData())
        XCTAssertNotNil(manager.getFileInfoData(for: id))

        manager.removeFileInfoData(for: id)

        XCTAssertNil(manager.getFileInfoData(for: id))
    }

    // MARK: - TerminalWindowData CRUD

    func testStoreTerminalData_ReturnsNonEmptyID() {
        let id = manager.storeTerminalData(makeTerminalData())
        XCTAssertFalse(id.isEmpty)
    }

    func testGetTerminalData_ReturnsStoredData() {
        let data = makeTerminalData()
        let id = manager.storeTerminalData(data)

        let retrieved = manager.getTerminalData(for: id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.connectionName, "Test Terminal")
        XCTAssertEqual(retrieved?.host, "term.example.com")
        XCTAssertEqual(retrieved?.username, "termuser")
    }

    func testGetTerminalData_NonexistentID_ReturnsNil() {
        let result = manager.getTerminalData(for: "nonexistent")
        XCTAssertNil(result)
    }

    func testRemoveTerminalData_SubsequentGetReturnsNil() {
        let id = manager.storeTerminalData(makeTerminalData())
        XCTAssertNotNil(manager.getTerminalData(for: id))

        manager.removeTerminalData(for: id)

        XCTAssertNil(manager.getTerminalData(for: id))
    }

    // MARK: - clearAllData

    func testClearAllData_RemovesAllTypes() {
        let browserID = manager.storeFileBrowserData(makeBrowserData())
        let editorID = manager.storeFileEditorData(makeEditorData())
        let infoID = manager.storeFileInfoData(makeFileInfoData())
        let terminalID = manager.storeTerminalData(makeTerminalData())

        // Verify all stored
        XCTAssertNotNil(manager.getFileBrowserData(for: browserID))
        XCTAssertNotNil(manager.getFileEditorData(for: editorID))
        XCTAssertNotNil(manager.getFileInfoData(for: infoID))
        XCTAssertNotNil(manager.getTerminalData(for: terminalID))

        manager.clearAllData()

        // Verify all removed
        XCTAssertNil(manager.getFileBrowserData(for: browserID))
        XCTAssertNil(manager.getFileEditorData(for: editorID))
        XCTAssertNil(manager.getFileInfoData(for: infoID))
        XCTAssertNil(manager.getTerminalData(for: terminalID))
    }

    // MARK: - Multiple Entries

    func testMultipleBrowserEntries_BothRetrievable() {
        let id1 = manager.storeFileBrowserData(makeBrowserData())
        let id2 = manager.storeFileBrowserData(makeBrowserData())

        XCTAssertNotEqual(id1, id2)
        XCTAssertNotNil(manager.getFileBrowserData(for: id1))
        XCTAssertNotNil(manager.getFileBrowserData(for: id2))
    }

    func testRemoveOneEntry_OtherStillRetrievable() {
        let id1 = manager.storeFileBrowserData(makeBrowserData())
        let id2 = manager.storeFileBrowserData(makeBrowserData())

        manager.removeFileBrowserData(for: id1)

        XCTAssertNil(manager.getFileBrowserData(for: id1))
        XCTAssertNotNil(manager.getFileBrowserData(for: id2))
    }
}
