//
//  ConnectionSidebarView.swift
//  macSCP
//
//  Single-column sidebar view for embedding in the unified browser window.
//  Combines folder navigation and connection list into one view.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConnectionSidebarView: View {
    @Bindable var viewModel: ConnectionListViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var newFolderName = ""
    @State private var folderToRename: Folder?
    @State private var renameText = ""

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Loading connections...")

            case .success:
                if viewModel.filteredConnections.isEmpty && viewModel.searchText.isEmpty {
                    emptyStateView
                } else if viewModel.filteredConnections.isEmpty {
                    EmptyStateView.noSearchResults
                } else {
                    connectionSections
                }

            case .error(let error):
                ErrorView(error: error) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Connections")
        .searchable(text: $viewModel.searchText, prompt: "Search connections")
            .accessibilityIdentifier("searchField")
        .task {
            await viewModel.loadData()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.isShowingNewConnectionSheet = true
                } label: {
                    Label("New Connection", systemImage: "square.and.pencil")
                }
                .help("New Connection")
                .accessibilityIdentifier("newConnectionButton")

                Button {
                    viewModel.isShowingNewFolderSheet = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .help("New Folder")
            }
        }
        // MARK: - Sheets
        .sheet(isPresented: $viewModel.isShowingNewConnectionSheet) {
            ConnectionFormSheet(
                mode: .create,
                folders: viewModel.folders,
                onSave: { connection, password in
                    Task {
                        await viewModel.saveConnection(connection, password: password)
                    }
                },
                onCancel: {
                    viewModel.isShowingNewConnectionSheet = false
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingEditConnectionSheet) {
            if let connection = viewModel.connectionToEdit {
                ConnectionFormSheet(
                    mode: .edit(connection),
                    savedPassword: viewModel.getSavedPassword(for: connection),
                    folders: viewModel.folders,
                    onSave: { updatedConnection, password in
                        Task {
                            await viewModel.updateConnection(updatedConnection, password: password)
                        }
                    },
                    onCancel: {
                        viewModel.isShowingEditConnectionSheet = false
                        viewModel.connectionToEdit = nil
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingPasswordPrompt) {
            if let connection = viewModel.connectionToConnect {
                PasswordPromptSheet(
                    connectionName: connection.name,
                    authMethod: connection.authMethod,
                    onConnect: { password in
                        viewModel.connectWithPassword(password)
                    },
                    onCancel: {
                        viewModel.cancelConnect()
                    }
                )
            }
        }
        // MARK: - Alerts
        .alert("New Folder", isPresented: $viewModel.isShowingNewFolderSheet) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let name = newFolderName.trimmed
                if !name.isEmpty {
                    Task { await viewModel.createFolder(name: name) }
                }
                newFolderName = ""
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert("Delete Folder", isPresented: $viewModel.isShowingDeleteFolderAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteFolder()
            }
            Button("Delete", role: .destructive) {
                if let folder = viewModel.folderToDelete {
                    Task {
                        await viewModel.deleteFolder(folder)
                    }
                }
            }
        } message: {
            if let folder = viewModel.folderToDelete {
                let count = viewModel.connectionCount(for: folder.id)
                Text("Are you sure you want to delete \"\(folder.name)\"? \(count > 0 ? "The \(count) connection(s) in this folder will be moved to All Connections." : "")")
            }
        }
        .alert("Rename Folder", isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField("Folder name", text: $renameText)
            Button("Rename") {
                let name = renameText.trimmed
                if !name.isEmpty, let folder = folderToRename {
                    Task { await viewModel.renameFolder(folder, to: name) }
                }
                folderToRename = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                folderToRename = nil
            }
        } message: {
            Text("Enter a new name for the folder.")
        }
        .errorAlert($viewModel.error)
        // MARK: - Terminal Window
        .onChange(of: viewModel.pendingTerminalWindowId) { _, windowId in
            if let windowId = windowId {
                logInfo("Opening terminal window with ID: \(windowId)", category: .ui)
                openWindow(id: WindowID.terminal, value: windowId)
                viewModel.clearPendingTerminalWindow()
            }
        }
    }

    // MARK: - Connection Sections

    @ViewBuilder
    private var connectionSections: some View {
        List {
            // Unfoldered connections ("All Connections") — always visible as drop target
            let unfoldered = viewModel.filteredConnections.filter { $0.folderId == nil }
            Label("All Connections", systemImage: "server.rack")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onDrop(of: [.connection], delegate: ConnectionDropDelegate(
                    targetFolder: nil,
                    viewModel: viewModel
                ))
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

            ForEach(unfoldered) { connection in
                connectionRow(connection)
            }

            // Folder sections
            ForEach(viewModel.folders) { folder in
                let folderConnections = viewModel.filteredConnections.filter { $0.folderId == folder.id }

                // Folder header row (droppable + context menu)
                Label(folder.name, systemImage: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onDrop(of: [.connection], delegate: ConnectionDropDelegate(
                        targetFolder: folder,
                        viewModel: viewModel
                    ))
                    .contextMenu {
                        Button {
                            folderToRename = folder
                            renameText = folder.name
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                if folderConnections.isEmpty {
                    Text("No connections")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                } else {
                    ForEach(folderConnections) { connection in
                        connectionRow(connection)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Connection Row

    @ViewBuilder
    private func connectionRow(_ connection: Connection) -> some View {
        ConnectionRowView(connection: connection)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.connectToServer(connection)
            }
            .onDrag {
                connection.toNSItemProvider()
            }
            .accessibilityIdentifier("connectionRow_\(connection.name)")
            .contextMenu {
                Button {
                    viewModel.connectToServer(connection)
                } label: {
                    Label("Open File Browser", systemImage: "folder")
                }

                Button {
                    viewModel.requestTerminal(for: connection)
                } label: {
                    Label("Open Terminal", systemImage: "terminal")
                }
                .disabled(connection.connectionType != .sftp)

                Divider()

                Button {
                    viewModel.editConnection(connection)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    Task {
                        await viewModel.duplicateConnection(connection)
                    }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Divider()

                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteConnection(connection)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "server.rack",
            title: "No Connections",
            message: "Add a new SSH connection to get started\nwith remote file management.",
            actionTitle: "Add Connection"
        ) {
            viewModel.isShowingNewConnectionSheet = true
        }
    }
}

// MARK: - Connection NSItemProvider helpers

extension Connection {
    func toNSItemProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        if let data = try? JSONEncoder().encode(self) {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.connection.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
        }
        return provider
    }

    static func from(_ provider: NSItemProvider) -> Connection? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.connection.identifier) else {
            return nil
        }
        var result: Connection?
        let semaphore = DispatchSemaphore(value: 0)
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.connection.identifier) { data, _ in
            defer { semaphore.signal() }
            guard let data = data else { return }
            result = try? JSONDecoder().decode(Connection.self, from: data)
        }
        semaphore.wait()
        return result
    }
}

// MARK: - Drop Delegate

struct ConnectionDropDelegate: DropDelegate {
    let targetFolder: Folder?
    let viewModel: ConnectionListViewModel

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.connection]).first else {
            return false
        }
        _ = item.loadDataRepresentation(forTypeIdentifier: UTType.connection.identifier) { data, _ in
            guard let data = data,
                  let connection = try? JSONDecoder().decode(Connection.self, from: data)
            else { return }
            Task { @MainActor in
                await viewModel.moveConnection(connection, to: targetFolder)
            }
        }
        return true
    }
}

// MARK: - Preview
#Preview {
    ConnectionSidebarView(viewModel: DependencyContainer.shared.makeConnectionListViewModel())
        .frame(width: 280)
}
