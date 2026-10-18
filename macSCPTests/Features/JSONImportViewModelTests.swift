//
//  JSONImportViewModelTests.swift
//  macSCPTests
//
//  Unit tests for JSONImportViewModel (Phase 6, IMP-04).
//  Covers SC#3 (savePassword=false, no Keychain write), duplicate detection,
//  and skip/overwrite/new batch-save resolution. Mirrors SSHConfigImportViewModelTests.
//

import XCTest
@testable import macSCP

@MainActor
final class JSONImportViewModelTests: XCTestCase {

    // MARK: - Properties

    private var mockRepository: MockConnectionRepository!
    private var mockKeychainService: MockKeychainService!
    private var tempDirs: [URL] = []

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockRepository = MockConnectionRepository()
        mockKeychainService = MockKeychainService()
    }

    override func tearDown() {
        for dir in tempDirs {
            try? FileManager.default.removeItem(at: dir)
        }
        tempDirs.removeAll()
        mockRepository = nil
        mockKeychainService = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeViewModel(existingConnections: [Connection] = []) -> JSONImportViewModel {
        JSONImportViewModel(
            connectionRepository: mockRepository,
            keychainService: mockKeychainService,
            existingConnections: existingConnections
        )
    }

    private func makeConnection(
        host: String,
        port: Int = 22,
        username: String = "",
        name: String? = nil
    ) -> Connection {
        Connection(name: name ?? host, host: host, port: port, username: username)
    }

    /// Writes a temp JSON export file using the codec (same format the import reads).
    private func writeTempJSON(connections: [Connection]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("JSONImportTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirs.append(tempDir)
        let url = tempDir.appendingPathComponent("connections.json")
        let file = ConnectionExportFile(
            version: ConnectionExportFile.currentVersion,
            exportedAt: Date(),
            appVersion: "1.3.0",
            connections: connections,
            folders: []
        )
        let data = try! ConnectionExportCodec.encoder().encode(file)
        try! data.write(to: url)
        return url
    }

    // MARK: - SC#3: Import sets savePassword=false + no Keychain write (T-6-03)

    func testImport_setsSavePasswordFalse() async {
        // Arrange — a connection with savePassword=true in the JSON
        let connection = makeConnection(host: "prod.example.com", username: "deploy")
        var connWithSavedPassword = connection
        connWithSavedPassword.savePassword = true

        let url = writeTempJSON(connections: [connWithSavedPassword])
        let vm = makeViewModel()

        // Act
        await vm.loadFile(at: url)
        XCTAssertEqual(vm.state, .parsed, "Should parse one connection")
        await vm.importSelected()

        // Assert — imported connection has savePassword forced false
        XCTAssertEqual(vm.state, .done(1))
        XCTAssertTrue(mockRepository.saveCalled, "New connection should be saved")
        XCTAssertFalse(
            mockRepository.lastSavedConnection!.savePassword,
            "SC#3: imported connection must have savePassword=false"
        )

        // Assert — NO Keychain write occurred (T-6-03)
        XCTAssertFalse(
            mockKeychainService.savePasswordCalled,
            "Import must not write to Keychain (T-6-03)"
        )
        XCTAssertFalse(
            mockKeychainService.saveS3CredentialsCalled,
            "Import must not write S3 credentials to Keychain"
        )
    }

    // MARK: - CR-01: Import clears orphaned folderId

    func testImport_clearsOrphanFolderId_newConnection() async {
        // CR-01: a connection imported with a folderId from the source
        // machine must have folderId reset to nil so it remains visible in
        // "All Connections" (the orphaned UUID matches no local folder).
        let connection = makeConnection(host: "server.example.com", username: "admin")
        var connWithFolder = connection
        connWithFolder.folderId = UUID() // simulates a non-local folder UUID

        let url = writeTempJSON(connections: [connWithFolder])
        let vm = makeViewModel()

        await vm.loadFile(at: url)
        XCTAssertEqual(vm.state, .parsed)
        await vm.importSelected()

        XCTAssertEqual(vm.state, .done(1))
        XCTAssertNotNil(mockRepository.lastSavedConnection)
        XCTAssertNil(
            mockRepository.lastSavedConnection?.folderId,
            "CR-01: imported connection must have folderId=nil to stay visible"
        )
    }

    func testImport_preservesFolderId_onOverwrite() async {
        // CR-01 (overwrite): the existing connection's valid local folderId
        // must be preserved — the imported (orphaned) value must NOT replace it.
        let localFolderId = UUID()
        var existing = makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A")
        existing.folderId = localFolderId
        let vm = makeViewModel(existingConnections: [existing])

        let jsonConn = makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A-imported")
        var connWithImportedFolder = jsonConn
        connWithImportedFolder.folderId = UUID() // different, orphaned UUID
        let url = writeTempJSON(connections: [connWithImportedFolder])

        await vm.loadFile(at: url)
        XCTAssertTrue(vm.entries[0].isDuplicate)
        vm.updateConflictAction(for: vm.entries[0].id, action: .overwrite)
        await vm.importSelected()

        XCTAssertEqual(vm.state, .done(1))
        XCTAssertTrue(mockRepository.updateCalled)
        XCTAssertEqual(
            mockRepository.lastUpdatedConnection?.folderId,
            localFolderId,
            "CR-01: overwrite must preserve existing connection's local folderId"
        )
    }

    // MARK: - WR-01: Overwrite clears stale Keychain credential (SC#3)

    func testOverwrite_clearsStaleKeychainCredential() async {
        // WR-01: overwrite must delete the existing connection's Keychain
        // credential so the user is re-prompted on next connect (SC#3).
        // Mirrors Phase 5 SSHConfigImportViewModel behavior.
        let existing = makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A")
        let vm = makeViewModel(existingConnections: [existing])

        let jsonConnection = makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A-imported")
        let url = writeTempJSON(connections: [jsonConnection])

        await vm.loadFile(at: url)
        XCTAssertTrue(vm.entries[0].isDuplicate)
        vm.updateConflictAction(for: vm.entries[0].id, action: .overwrite)
        await vm.importSelected()

        XCTAssertEqual(vm.state, .done(1))
        XCTAssertTrue(mockRepository.updateCalled, "Overwrite path should call update")
        XCTAssertTrue(
            mockKeychainService.deletePasswordCalled,
            "WR-01: overwrite must clear stale Keychain credential (SC#3)"
        )
        XCTAssertEqual(
            mockKeychainService.lastDeleteConnectionId,
            existing.id,
            "Should delete credential for the existing connection id"
        )
        XCTAssertFalse(
            mockKeychainService.savePasswordCalled,
            "Import must not write to Keychain (T-6-03)"
        )
    }

    // MARK: - Duplicate Detection (Host+User+Port)

    func testDuplicateDetection_marksConflicts() async {
        // Arrange — existing connection matches the JSON entry
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let jsonConnection = makeConnection(host: "10.0.0.1", port: 22, username: "alice")
        let url = writeTempJSON(connections: [jsonConnection])

        // Act
        await vm.loadFile(at: url)

        // Assert
        XCTAssertEqual(vm.state, .parsed)
        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertTrue(
            vm.entries[0].isDuplicate,
            "Entry with matching host+user+port should be flagged as duplicate"
        )
        XCTAssertTrue(vm.hasConflicts)
    }

    // MARK: - skip / overwrite / new resolution

    func testImportSelected_skipOverwriteNew() async {
        // Arrange — two existing connections that will match JSON entries 0 & 1
        let existingA = makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A")
        let existingB = makeConnection(host: "server-b.com", port: 22, username: "bob", name: "B")
        let existing = [existingA, existingB]
        let vm = makeViewModel(existingConnections: existing)

        // JSON: entry0 (duplicate of A), entry1 (duplicate of B), entry2 (new)
        let jsonConnections = [
            makeConnection(host: "server-a.com", port: 22, username: "alice", name: "A-imported"),
            makeConnection(host: "server-b.com", port: 22, username: "bob", name: "B-imported"),
            makeConnection(host: "server-c.com", port: 22, username: "carol", name: "C-new")
        ]
        let url = writeTempJSON(connections: jsonConnections)

        // Act — load, then set entry1 to overwrite (entry0 stays skip by default)
        await vm.loadFile(at: url)
        XCTAssertTrue(vm.entries[0].isDuplicate, "Entry 0 should be a duplicate")
        XCTAssertTrue(vm.entries[1].isDuplicate, "Entry 1 should be a duplicate")
        XCTAssertFalse(vm.entries[2].isDuplicate, "Entry 2 should be new")

        let overwriteId = vm.entries[1].id
        vm.updateConflictAction(for: overwriteId, action: .overwrite)

        await vm.importSelected()

        // Assert — 2 imported (overwrite + new); skip-duplicate excluded
        XCTAssertEqual(vm.state, .done(2), "Should import overwrite + new (skip excluded)")
        XCTAssertTrue(mockRepository.updateCalled, "Overwrite path should call update")
        XCTAssertTrue(mockRepository.saveCalled, "New path should call save")

        // Overwrite preserves existing.id
        XCTAssertEqual(
            mockRepository.lastUpdatedConnection?.id,
            existingB.id,
            "Overwrite should preserve existing connection id"
        )
    }
}
