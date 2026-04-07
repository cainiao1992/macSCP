//
//  SidebarView.swift
//  macSCP
//
//  Sidebar view for connection folders - Minimal macOS style
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @State private var folderToRename: Folder?
    @State private var renameText = ""
    @State private var isShowingRenameAlert = false

    var body: some View {
        List(selection: $viewModel.selectedSidebarItem) {
            // All Connections
            NavigationLink(value: SidebarSelection.allConnections) {
                Label {
                    Text("All Connections")
                        .accessibilityIdentifier("allConnectionsRow")
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .accessibilityIdentifier("allConnectionsRow")
            .dropDestination(for: Connection.self) { connections, _ in
                for connection in connections {
                    Task { await viewModel.moveConnection(connection, to: nil) }
                }
                return true
            }

            // Folders Section
            Section("Folders") {
                ForEach(viewModel.folders) { folder in
                    NavigationLink(value: SidebarSelection.folder(folder.id)) {
                        FolderRowView(
                            folder: folder,
                            connectionCount: viewModel.connectionCount(for: folder.id)
                        )
                    }
                    .dropDestination(for: Connection.self) { connections, _ in
                        for connection in connections {
                            Task { await viewModel.moveConnection(connection, to: folder) }
                        }
                        return true
                    }
                    .contextMenu {
                        Button {
                            folderToRename = folder
                            renameText = folder.name
                            isShowingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.confirmDeleteFolder(folder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    viewModel.reorderFolders(from: source, to: destination)
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.isShowingNewFolderSheet = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("New Folder")
            }
        }
        .alert("Rename Folder", isPresented: $isShowingRenameAlert) {
            TextField("Folder name", text: $renameText)
            Button("Rename") {
                let name = renameText.trimmed
                if !name.isEmpty, let folder = folderToRename {
                    Task { await viewModel.renameFolder(folder, to: name) }
                }
                folderToRename = nil
                renameText = ""
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                folderToRename = nil
                renameText = ""
            }
        } message: {
            Text("Enter a new name for the folder.")
        }
    }
}

// MARK: - Folder Row
struct FolderRowView: View {
    let folder: Folder
    let connectionCount: Int

    var body: some View {
        Label {
            Text(folder.name)
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .frame(width: 20, height: 20)
        }
        .badge("\(connectionCount)")
    }
}

// MARK: - Preview
#Preview {
    SidebarView(viewModel: DependencyContainer.shared.makeConnectionListViewModel())
        .frame(width: 250)
}
