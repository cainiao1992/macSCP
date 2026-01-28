//
//  macSCPApp.swift
//  macSCP
//
//  Created by Nevil Macwan on 09/10/25.
//

import SwiftData
import SwiftUI

@main
struct macSCPApp: App {
    var sharedModelContainer = DatabaseManager.shared
        .createModelContainerWithRecovery()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: WindowID.sshExplorer, for: String.self) {
            $connectionId in
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
