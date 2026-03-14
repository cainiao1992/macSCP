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
    var body: some View {
        List(selection: $viewModel.selectedSidebarItem) {
            // All Connections
            NavigationLink(value: SidebarSelection.allConnections) {
                Label {
                    Text("All Connections")
                } icon: {
                    Image(systemName: "server.rack")
                        .foregroundStyle(Color.accentColor)
                }
            }

            // Folders Section
            Section("Folders") {
                ForEach(viewModel.folders) { folder in
                    NavigationLink(value: SidebarSelection.folder(folder.id)) {
                        FolderRowView(
                            folder: folder,
                            connectionCount: viewModel.connectionCount(for: folder.id),
                            onRename: { newName in
                                Task {
                                    await viewModel.renameFolder(folder, to: newName)
                                }
                            },
                            onDelete: {
                                viewModel.confirmDeleteFolder(folder)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
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
    }
}

// MARK: - Folder Row
struct FolderRowView: View {
    let folder: Folder
    let connectionCount: Int
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isRenaming = false
    @State private var newName: String = ""

    var body: some View {
        Label {
            if isRenaming {
                TextField("Name", text: $newName)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if !newName.trimmed.isEmpty {
                            onRename(newName.trimmed)
                        }
                        isRenaming = false
                    }
                    .onAppear {
                        newName = folder.name
                    }
            } else {
                Text(folder.name)
            }
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .frame(width: 16, height: 16)
        }
        .badge(connectionCount)
        .contextMenu {
            Button {
                newName = folder.name
                isRenaming = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SidebarView(viewModel: DependencyContainer.shared.makeConnectionListViewModel())
        .frame(width: 250)
}
