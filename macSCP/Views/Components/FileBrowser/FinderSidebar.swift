//
//  FinderSidebar.swift
//  macSCP
//
//  Sidebar navigation for file browser
//

import SwiftUI

struct FinderSidebar: View {
    let currentPath: String
    let onNavigate: (String) -> Void

    var body: some View {
        List {
            Section("Favorites") {
                Label("Home", systemImage: "house.fill")
                    .onTapGesture { onNavigate("~") }

                Label("Root", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/") }
            }

            Section("Locations") {
                Label("etc", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/etc") }

                Label("var", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/var") }

                Label("usr", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/usr") }

                Label("tmp", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/tmp") }
            }
        }
        .listStyle(.sidebar)
    }
}
