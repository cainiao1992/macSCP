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
                        }
                        .onDelete(perform: deleteFolders)

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

    private func deleteFolders(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(folders[index])
            }
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
