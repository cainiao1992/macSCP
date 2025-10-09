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

    @State private var selectedFolder: ConnectionFolder?
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
                List(selection: $selectedFolder) {
                    Section("Folders") {
                        ForEach(folders) { folder in
                            NavigationLink(value: folder) {
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
            // Main content showing connections in selected folder
            if let folder = selectedFolder {
                FolderContentView(folder: folder)
            } else {
                NoFolderSelectedView(onCreateFolder: { showingNewFolderSheet = true })
            }
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderView(folderName: $newFolderName, onCreate: {
                createFolder()
            })
        }
        .sheet(isPresented: $showingNewConnectionSheet) {
            NewConnectionSheetView(folder: selectedFolder)
        }
        .alert("Delete Folder", isPresented: $showingDeleteFolderConfirmation, presenting: folderToDelete) { folder in
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteFolder(folder)
            }
        } message: { folder in
            if folder.connections.isEmpty {
                Text("Are you sure you want to delete '\(folder.name)'?")
            } else {
                Text("Are you sure you want to delete '\(folder.name)' and all \(folder.connections.count) connection(s) inside? This action cannot be undone.")
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
        selectedFolder = folder
    }

    private func deleteFolder(_ folder: ConnectionFolder) {
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
            if selectedFolder?.id == folder.id {
                selectedFolder = nil
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
