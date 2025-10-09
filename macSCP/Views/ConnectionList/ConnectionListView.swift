//
//  ConnectionListView.swift
//  macSCP
//
//  Main window showing folders and connections
//

import SwiftUI
import SwiftData

struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query private var folders: [ConnectionFolder]
    @Query private var allConnections: [SSHConnection]

    enum SidebarSelection: Hashable {
        case all
        case folder(ConnectionFolder)
    }

    @State private var selection: SidebarSelection? = .all
    @State private var showingNewFolderSheet = false
    @State private var showingNewConnectionSheet = false
    @State private var showingDeleteFolderConfirmation = false
    @State private var folderToDelete: ConnectionFolder?
    @State private var newFolderName = ""

    var unorganizedConnections: [SSHConnection] {
        allConnections.filter { $0.folder == nil }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar with folders
            VStack(spacing: 0) {
                List(selection: $selection) {
                    // All Connections
                    NavigationLink(value: SidebarSelection.all) {
                        Label("All", systemImage: "tray.full.fill")
                    }

                    Section("Folders") {
                        ForEach(folders) { folder in
                            NavigationLink(value: SidebarSelection.folder(folder)) {
                                Label(folder.name, systemImage: "folder.fill")
                            }
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    folderToDelete = folder
                                    showingDeleteFolderConfirmation = true
                                }) {
                                    Label("Delete Folder", systemImage: "trash")
                                }
                            }
                        }

                        // Add folder button in the list
                        Button(action: { showingNewFolderSheet = true }) {
                            Label("New Folder", systemImage: "plus.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("macSCP")
            }
        } detail: {
            // Main content showing connections
            switch selection {
            case .all:
                AllConnectionsView(allConnections: allConnections)
            case .folder(let folder):
                FolderContentView(folder: folder)
            case .none:
                NoFolderSelectedView(onCreateFolder: { showingNewFolderSheet = true })
            }
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderView(folderName: $newFolderName, onCreate: {
                createFolder()
            })
        }
        .sheet(isPresented: $showingNewConnectionSheet) {
            if case .folder(let folder) = selection {
                NewConnectionSheetView(folder: folder)
            } else {
                NewConnectionSheetView(folder: nil)
            }
        }
        .alert("Delete Folder", isPresented: $showingDeleteFolderConfirmation, presenting: folderToDelete) { folder in
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }

            if !folder.connections.isEmpty {
                Button("Keep Connections", role: .none) {
                    deleteFolderOnly(folder)
                }
                Button("Delete All", role: .destructive) {
                    deleteFolderAndConnections(folder)
                }
            } else {
                Button("Delete Folder", role: .destructive) {
                    deleteFolderOnly(folder)
                }
            }
        } message: { folder in
            if folder.connections.isEmpty {
                Text("Are you sure you want to delete '\(folder.name)'?")
            } else {
                Text("The folder '\(folder.name)' contains \(folder.connections.count) connection(s). Do you want to keep the connections or delete everything?")
            }
        }
    }

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let folder = ConnectionFolder(name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(folder)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save folder: \(error)")
        }

        newFolderName = ""
        showingNewFolderSheet = false
        selection = .folder(folder)
    }

    private func deleteFolderOnly(_ folder: ConnectionFolder) {
        withAnimation {
            // Move all connections to no folder (unorganized)
            for connection in folder.connections {
                connection.folder = nil
            }

            // Delete just the folder
            modelContext.delete(folder)

            // Clear selection if we're deleting the selected folder
            if case .folder(let selectedFolder) = selection, selectedFolder.id == folder.id {
                selection = .all
            }

            folderToDelete = nil
        }
    }

    private func deleteFolderAndConnections(_ folder: ConnectionFolder) {
        withAnimation {
            // Delete all saved passwords for connections in this folder
            for connection in folder.connections {
                if connection.shouldSavePassword {
                    _ = KeychainManager.shared.deletePassword(for: connection.id.uuidString)
                }
            }

            // Delete the folder (SwiftData will cascade delete connections)
            modelContext.delete(folder)

            // Clear selection if we're deleting the selected folder
            if case .folder(let selectedFolder) = selection, selectedFolder.id == folder.id {
                selection = .all
            }

            folderToDelete = nil
        }
    }
}

// MARK: - No Folder Selected
struct NoFolderSelectedView: View {
    let onCreateFolder: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Folder Selected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create a folder to organize your SSH connections")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onCreateFolder) {
                Label("Create New Folder", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ConnectionListView()
        .modelContainer(for: [ConnectionFolder.self, SSHConnection.self], inMemory: true)
}
