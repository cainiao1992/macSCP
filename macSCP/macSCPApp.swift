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
    }
}
