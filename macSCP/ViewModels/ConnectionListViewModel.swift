//
//  ConnectionListViewModel.swift
//  macSCP
//
//  Created by Nevil Macwan on 29/01/26.
//

import Combine
import SwiftData
import SwiftUI
import os

@MainActor
class ConnectionListViewModel: ObservableObject {
    private let modelContext: ModelContext
    private let keychainManager: KeychainManagerProtocol

    init(
        modelContext: ModelContext,
        keychainManager: KeychainManagerProtocol = KeychainManager.shared
    ) {
        self.modelContext = modelContext
        self.keychainManager = keychainManager
    }

    // MARK: - Folder Operations

    func createFolder(name: String) -> ConnectionFolder? {
        guard !name.isEmptyOrWhitespace else { return nil }

        let folder = ConnectionFolder(name: name.trimmed)
        modelContext.insert(folder)

        do {
            try modelContext.save()
            return folder
        } catch {
            AppLogger.database.error("Failed to save folder: \(error)")
            return nil
        }
    }

    func deleteFolderOnly(_ folder: ConnectionFolder) {
        for connection in folder.connections {
            connection.folder = nil
        }
        modelContext.delete(folder)
    }

    func deleteFolderAndConnections(_ folder: ConnectionFolder) {
        for connection in folder.connections {
            if connection.shouldSavePassword {
                _ = keychainManager.deletePassword(
                    for: connection.id.uuidString
                )
            }
        }
        modelContext.delete(folder)
    }
}
