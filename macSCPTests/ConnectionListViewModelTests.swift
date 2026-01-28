//
//  ConnectionListViewModel.swift
//  macSCP
//
//  Created by Nevil Macwan on 29/01/26.
//

import SwiftData
import XCTest

@testable import macSCP

// Mock KeychainManager for testing
class MockKeychainManager: KeychainManagerProtocol {
    var deletedConnectionIds: [String] = []

    func savePassword(_ password: String, for connectionId: String) -> Bool {
        true
    }
    func getPassword(for connectionId: String) -> String? { nil }
    func deletePassword(for connectionId: String) -> Bool {
        deletedConnectionIds.append(connectionId)
        return true
    }
    func updatePassword(_ password: String, for connectionId: String) -> Bool {
        true
    }
}

@MainActor
final class ConnectionListViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var mockKeychain: MockKeychainManager!
    var viewModel: ConnectionListViewModel!

    override func setUp() async throws {
        modelContainer = try ModelContainer(
            for: ConnectionFolder.self,
            SSHConnection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = modelContainer.mainContext
        mockKeychain = MockKeychainManager()
        viewModel = ConnectionListViewModel(
            modelContext: modelContext,
            keychainManager: mockKeychain
        )
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        mockKeychain = nil
        viewModel = nil
    }

    func testCreateFolder_withValidName_returnsFolder() async {
        let folder = viewModel.createFolder(name: "Test Folder")

        XCTAssertNotNil(folder)
        XCTAssertEqual(folder?.name, "Test Folder")
    }

    func testCreateFolder_withEmptyName_returnsNil() async {
        let folder = viewModel.createFolder(name: "   ")

        XCTAssertNil(folder)
    }

    func testCreateFolder_trimsWhitespace() async {
        let folder = viewModel.createFolder(name: "  Trimmed Name  ")

        XCTAssertEqual(folder?.name, "Trimmed Name")
    }

    func testDeleteFolderOnly_removesFolder() async {
        let folder = viewModel.createFolder(name: "To Delete")!

        viewModel.deleteFolderOnly(folder)

        // Folder should be marked for deletion
        XCTAssertTrue(folder.isDeleted)
    }

    func testDeleteFolderAndConnections_deletesPasswords() async {
        let folder = viewModel.createFolder(name: "Folder")!
        let connection = SSHConnection(
            name: "Test",
            host: "localhost",
            port: 22,
            username: "user",
            authenticationType: .password,
            savePassword: true,
            folder: folder
        )
        modelContext.insert(connection)

        viewModel.deleteFolderAndConnections(folder)

        XCTAssertTrue(
            mockKeychain.deletedConnectionIds.contains(connection.id.uuidString)
        )
    }
}
