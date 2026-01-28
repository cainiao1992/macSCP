//
//  DatabaseManager.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import Foundation
import SwiftData

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private init() {}
    
    // MARK: - Model Container
    func createModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SSHConnection.self, ConnectionFolder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
    }
    
    // MARK: - Database Reset
    func resetDatabase() {
        let fileManager = FileManager.default
                                                                                                                                           
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
                                                                                                                                           
        let bundleID = Bundle.main.bundleIdentifier ?? AppConstants.defaultBundleID
        let storeURL = appSupport.appendingPathComponent(bundleID).appendingPathComponent("default.store")
                                                                                                                                           
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
        try? fileManager.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
    }
}
