//
//  SSHConfigImportViewModelTests.swift
//  macSCPTests
//
//  Unit tests for SSHConfigImportViewModel — state machine, duplicate detection, batch save
//

import XCTest
@testable import macSCP

@MainActor
final class SSHConfigImportViewModelTests: XCTestCase {

    // MARK: - Properties

    private var viewModel: SSHConfigImportViewModel!
    private var mockRepository: MockConnectionRepository!
    private var mockKeychainService: MockKeychainService!
    private var parser: SSHConfigParser!
    private var tempDirs: [URL] = []

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockRepository = MockConnectionRepository()
        mockKeychainService = MockKeychainService()
        parser = SSHConfigParser()
    }

    override func tearDown() {
        for dir in tempDirs {
            try? FileManager.default.removeItem(at: dir)
        }
        tempDirs.removeAll()
        viewModel = nil
        mockRepository = nil
        mockKeychainService = nil
        parser = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeViewModel(existingConnections: [Connection] = []) -> SSHConfigImportViewModel {
        SSHConfigImportViewModel(
            parser: parser,
            connectionRepository: mockRepository,
            keychainService: mockKeychainService,
            existingConnections: existingConnections
        )
    }

    private func makeConnection(
        host: String,
        port: Int = 22,
        username: String = ""
    ) -> Connection {
        Connection(name: host, host: host, port: port, username: username)
    }

    private func writeTempConfig(_ content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSHConfigImportTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempDirs.append(tempDir)
        let url = tempDir.appendingPathComponent("config")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Duplicate Detection

    func testParse_detectsDuplicatesAgainstExistingConnections() async {
        // Arrange
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            HostName 10.0.0.1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert
        XCTAssertEqual(vm.state, .parsed)
        XCTAssertEqual(vm.entries.count, 1)
        XCTAssertTrue(vm.entries[0].isDuplicate)
    }

    func testParse_duplicateDetection_caseInsensitiveHost() async {
        // Arrange
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host SERVER1
            HostName 10.0.0.1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert
        XCTAssertTrue(vm.entries[0].isDuplicate)
    }

    func testParse_duplicateDetection_caseSensitiveUsername() async {
        // Arrange
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "Alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            HostName 10.0.0.1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert — different username case means NOT a duplicate
        XCTAssertFalse(vm.entries[0].isDuplicate)
    }

    func testParse_conflictActionDefaultsToSkip() async {
        // Arrange
        let existing = [makeConnection(host: "server1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert
        XCTAssertEqual(vm.entries[0].conflictAction, .skip)
    }

    // MARK: - Import (Batch Save)

    func testImportSelected_createsNewConnections() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host server1
            HostName 10.0.0.1
            Port 2222
            User alice

        Host server2
            HostName 10.0.0.2
            Port 22
            User bob
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        XCTAssertEqual(vm.state, .done(2))
        XCTAssertTrue(mockRepository.saveCalled)
    }

    func testImportSelected_excludesDuplicatesWithSkip() async {
        // Arrange
        let existing = [makeConnection(host: "server1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Default conflict action is .skip
        // Act
        await vm.importSelected()

        // Assert — nothing imported because duplicate is skipped
        XCTAssertEqual(vm.state, .done(0))
        XCTAssertFalse(mockRepository.saveCalled)
    }

    func testImportSelected_updatesExistingOnOverwrite() async {
        // Arrange
        let existingConn = makeConnection(host: "new-host.com", port: 22, username: "alice")
        mockRepository.mockConnections = [existingConn]
        let vm = makeViewModel(existingConnections: [existingConn])

        let config = """
        Host server1
            HostName new-host.com
            Port 22
            User alice
            IdentityFile ~/.ssh/new_key
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Set conflict action to overwrite
        XCTAssertTrue(vm.entries[0].isDuplicate, "Entry should be detected as duplicate")
        let entryId = vm.entries[0].id
        vm.updateConflictAction(for: entryId, action: .overwrite)

        // Act
        await vm.importSelected()

        // Assert
        XCTAssertEqual(vm.state, .done(1))
        XCTAssertTrue(mockRepository.updateCalled)
    }

    func testImportSelected_mapsFieldsCorrectly() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host myserver
            HostName real-host.com
            Port 2222
            User deploy
            IdentityFile ~/.ssh/deploy_key
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        XCTAssertTrue(mockRepository.saveCalled)
        let saved = mockRepository.lastSavedConnection!
        XCTAssertEqual(saved.name, "myserver")
        XCTAssertEqual(saved.host, "real-host.com")
        XCTAssertEqual(saved.port, 2222)
        XCTAssertEqual(saved.username, "deploy")
        XCTAssertEqual(saved.privateKeyPath, ("~/.ssh/deploy_key" as NSString).expandingTildeInPath)
        XCTAssertEqual(saved.authMethod, .privateKey)
        XCTAssertEqual(saved.connectionType, .sftp)
        XCTAssertEqual(saved.iconName, "server.rack")
        XCTAssertFalse(saved.savePassword)
        XCTAssertTrue(saved.tags.isEmpty)
        XCTAssertNil(saved.folderId)
    }

    func testImportSelected_hostFallsBackToHostValueWhenHostNameNil() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host myserver
            Port 22
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        let saved = mockRepository.lastSavedConnection!
        XCTAssertEqual(saved.host, "myserver")
    }

    func testImportSelected_authMethodPasswordWhenNoIdentityFile() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host myserver
            HostName example.com
            User admin
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        let saved = mockRepository.lastSavedConnection!
        XCTAssertEqual(saved.authMethod, .password)
    }

    func testImportSelected_authMethodPrivateKeyWhenIdentityFilePresent() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host myserver
            IdentityFile ~/.ssh/key
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        let saved = mockRepository.lastSavedConnection!
        XCTAssertEqual(saved.authMethod, .privateKey)
    }

    // MARK: - State Machine

    func testParseFile_transitionsToParsedOnSuccess() async {
        // Arrange
        let vm = makeViewModel()
        let config = """
        Host server1
            HostName 10.0.0.1
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert
        XCTAssertEqual(vm.state, .parsed)
        XCTAssertEqual(vm.entries.count, 1)
    }

    func testParseFile_transitionsToParsedEmptyOnNoEntries() async {
        // Arrange
        let vm = makeViewModel()
        let config = """
        Host *
            ServerAliveInterval 60
        """
        let url = writeTempConfig(config)

        // Act
        await vm.parseFile(at: url)

        // Assert
        XCTAssertEqual(vm.state, .parsedEmpty)
        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertEqual(vm.wildcardCount, 1)
    }

    func testParseFile_transitionsToErrorOnFailure() async {
        // Arrange
        let vm = makeViewModel()
        let url = URL(fileURLWithPath: "/non-existent-file-\(UUID().uuidString)")

        // Act
        await vm.parseFile(at: url)

        // Assert
        if case .error = vm.state {
            // Expected
        } else {
            XCTFail("Expected .error state, got \(vm.state)")
        }
    }

    func testImportSelected_transitionsToDoneOnSuccess() async {
        // Arrange
        let vm = makeViewModel()
        let config = """
        Host server1
            HostName 10.0.0.1
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Act
        await vm.importSelected()

        // Assert
        XCTAssertEqual(vm.state, .done(1))
    }

    // MARK: - Selection

    func testToggleSelection_removesFromSelectedIds() async {
        // Arrange
        let vm = makeViewModel()
        let config = """
        Host server1
            HostName 10.0.0.1

        Host server2
            HostName 10.0.0.2
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Initially all selected
        XCTAssertEqual(vm.selectedCount, 2)

        // Act
        vm.toggleSelection(for: vm.entries[0])

        // Assert
        XCTAssertEqual(vm.selectedCount, 1)
        XCTAssertFalse(vm.selectedIds.contains(vm.entries[0].id))
    }

    func testSelectAll_selectsAllEntries() async {
        // Arrange
        let vm = makeViewModel()
        let config = """
        Host server1
            HostName 10.0.0.1

        Host server2
            HostName 10.0.0.2
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Deselect all
        vm.selectAll(false)
        XCTAssertEqual(vm.selectedCount, 0)

        // Act
        vm.selectAll(true)

        // Assert
        XCTAssertEqual(vm.selectedCount, 2)
    }

    // MARK: - Computed Properties

    func testEffectiveImportCount_excludesDuplicatesWithSkip() async {
        // Arrange
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            HostName 10.0.0.1
            Port 22
            User alice

        Host server2
            HostName 10.0.0.2
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Assert — server1 is duplicate with .skip, server2 is new
        XCTAssertEqual(vm.effectiveImportCount, 1)
    }

    func testHasConflicts_returnsTrueWhenDuplicatesExist() async {
        // Arrange
        let existing = [makeConnection(host: "10.0.0.1", port: 22, username: "alice")]
        let vm = makeViewModel(existingConnections: existing)

        let config = """
        Host server1
            HostName 10.0.0.1
            Port 22
            User alice
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Assert
        XCTAssertTrue(vm.hasConflicts)
    }

    func testHasConflicts_returnsFalseWhenNoDuplicates() async {
        // Arrange
        let vm = makeViewModel()

        let config = """
        Host server1
            HostName 10.0.0.1
        """
        let url = writeTempConfig(config)
        await vm.parseFile(at: url)

        // Assert
        XCTAssertFalse(vm.hasConflicts)
    }
}
