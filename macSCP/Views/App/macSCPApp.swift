//
//  macSCPApp.swift
//  macSCP
//
//  Created by Nevil Macwan on 09/10/25.
//

import SwiftUI
import SwiftData

@main
struct macSCPApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            // Try to create the container with auto-migration
            return try DatabaseManager.shared.createModelContainer()
        } catch {
            // If migration fails, reset the database
            print("Failed to create ModelContainer with error: \(error)")
            print("Attempting to reset database...")

            DatabaseManager.shared.resetDatabase()

            // Try again with a clean slate
            do {
                return try DatabaseManager.shared.createModelContainer()
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: WindowID.sshExplorer, for: String.self) { $connectionId in
            if let connectionId = connectionId {
                SSHFileExplorerWindow(connectionId: connectionId)
            }
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: WindowID.fileEditor, for: String.self) { $editorId in
            if let editorId = editorId {
                FileEditorWindowView(editorId: editorId)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(WindowSize.fileEditor)

        WindowGroup(id: WindowID.fileInfo, for: String.self) { $infoId in
            if let infoId = infoId {
                FileInfoContainerView(infoId: infoId)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(WindowSize.fileInfo)
        .windowResizability(.contentSize)
    }
}
