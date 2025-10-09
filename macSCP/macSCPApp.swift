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
        let schema = Schema([
            Item.self,
            SSHConnection.self,
            ConnectionFolder.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: "ssh-explorer", for: String.self) { $connectionId in
            if let connectionId = connectionId {
                SSHFileExplorerWindow(connectionId: connectionId)
            }
        }
        .modelContainer(sharedModelContainer)

        WindowGroup(id: "file-editor", for: String.self) { $editorId in
            if let editorId = editorId {
                FileEditorWindowView(editorId: editorId)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)

        WindowGroup(id: "file-info", for: String.self) { $infoId in
            if let infoId = infoId {
                FileInfoContainerView(infoId: infoId)
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 400, height: 500)
        .windowResizability(.contentSize)
    }
}
