//
//  DatabaseManager.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import Foundation
import SwiftData
import os

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private init() {}
    
    // MARK: - Model Container with Recovery
    func createModelContainerWithRecovery() -> ModelContainer {
        AppLogger.database.info("Creating database container...")
        do {
            return try createModelContainer()
        } catch {
            AppLogger.database.error("Failed to create database container: \(error)")
            AppLogger.database.warning("Resetting database...")
            resetDatabase()
            do {
                AppLogger.database.info("Retrying database container creation...")
                return try createModelContainer()
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }

    // MARK: - Model Container
    private func createModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SSHConnection.self, ConnectionFolder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
    }
    
    // MARK: - Database Reset
    private func resetDatabase() {
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
