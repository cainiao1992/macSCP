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
        .toolbar(id: "connectionSidebarToolbar") {
            ToolbarItem(id: "openConnection", placement: .primaryAction) {
                Button {
                    if let connection = viewModel.selectedConnection {
                        viewModel.connectToServer(connection)
                    }
                } label: {
                    Label("Open Connection", systemImage: "arrow.right.square")
                        .labelStyle(.iconOnly)
                }
                .help("Open selected connection")
                .disabled(viewModel.selectedConnection == nil)
            }

            ToolbarItem(id: "newConnection", placement: .primaryAction) {
                Button {
                    viewModel.isShowingNewConnectionSheet = true
                } label: {
                    Label("New Connection", systemImage: "square.and.pencil")
                        .labelStyle(.iconOnly)
                }
                .help("New Connection")
                .accessibilityIdentifier("newConnectionButton")
            }

            ToolbarItem(id: "newFolder", placement: .primaryAction) {
                Button {
                    viewModel.isShowingNewFolderSheet = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .help("New Folder")
            }

            ToolbarItem(id: "importSSHConfig", placement: .primaryAction) {
                Button {
                    viewModel.isShowingImportSheet = true
                } label: {
                    Label("Import SSH Config", systemImage: "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .help("Import SSH Config")
                .accessibilityLabel("Import SSH config")
                .accessibilityHint("Open the SSH config import sheet")
            }

            ToolbarItem(id: "importJSONConnections", placement: .primaryAction) {
                Button {
                    viewModel.isShowingJSONImportSheet = true
                } label: {
                    Label("Import Connections", systemImage: "square.and.arrow.down.on.square")
                        .labelStyle(.iconOnly)
                }
                .help("Import Connections (JSON)")
                .accessibilityLabel("Import connections")
                .accessibilityHint("Open the JSON connections import sheet")
            }

            ToolbarItem(id: "exportConnections", placement: .primaryAction) {
                Button {
                    viewModel.isShowingExportChoice = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .help("Export Connections")
                .accessibilityLabel("Export connections")
                .accessibilityHint("Choose to export all or the selected connection to JSON")
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
                },
                onTestConnection: { connection, password in
                    Task {
                        await viewModel.testConnection(connection, password: password)
                    }
                },
                testConnectionState: viewModel.testConnectionState,
                onResetTestState: {
                    viewModel.resetTestConnectionState()
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
                    },
                    onTestConnection: { connection, password in
                        Task {
                            await viewModel.testConnection(connection, password: password)
                        }
                    },
                    testConnectionState: viewModel.testConnectionState,
                    onResetTestState: {
                        viewModel.resetTestConnectionState()
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingPasswordPrompt) {
            if let connection = viewModel.connectionToConnect {
                PasswordPromptSheet(
                    connection: connection,
                    connectionError: viewModel.connectionError,
                    isConnecting: viewModel.isConnecting,
                    onConnect: { password in
                        viewModel.connectWithPassword(password)
                    },
                    onCancel: {
                        viewModel.cancelConnect()
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingImportSheet) {
            let importViewModel = DependencyContainer.shared.makeSSHConfigImportViewModel(
                existingConnections: viewModel.connections
            )
            SSHConfigImportSheet(viewModel: importViewModel)
                .onAppear {
                    importViewModel.onDismiss = {
                        viewModel.isShowingImportSheet = false
                    }
                }
        }
        .onChange(of: viewModel.isShowingImportSheet) { _, isShowing in
            if !isShowing {
                Task { await viewModel.loadData() }
            }
        }
        .sheet(isPresented: $viewModel.isShowingJSONImportSheet) {
            let jsonImportViewModel = DependencyContainer.shared.makeJSONImportViewModel(
                existingConnections: viewModel.connections
            )
            JSONImportSheet(viewModel: jsonImportViewModel)
                .onAppear {
                    jsonImportViewModel.onDismiss = {
                        viewModel.isShowingJSONImportSheet = false
                    }
                }
        }
        .onChange(of: viewModel.isShowingJSONImportSheet) { _, isShowing in
            if !isShowing {
                Task { await viewModel.loadData() }
            }
        }
        .confirmationDialog(
            "Export Connections",
            isPresented: $viewModel.isShowingExportChoice,
            titleVisibility: .visible
        ) {
            Button("Export All (\(viewModel.connections.count))") {
                viewModel.exportConnections(.all)
            }
            Button("Export Selected") {
                viewModel.exportConnections(.selected)
            }
            .disabled(viewModel.selectedConnectionId == nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to export all connections or only the selected one.")
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                // Recent group (last 5 used connections)
                let recent = viewModel.recentConnections
                if !recent.isEmpty {
                    sectionHeader("Recent", systemImage: "clock", color: .blue)
                    ForEach(recent) { connection in
                        connectionRow(connection)
                    }
                }

                // Favorites group
                let favorites = viewModel.filteredConnections.filter(\.isFavorite)
                if !favorites.isEmpty {
                    sectionHeader("Favorites", systemImage: "star.fill", color: .yellow)
                    ForEach(favorites) { connection in
                        connectionRow(connection)
                    }
                }

                // Unfoldered connections ("All Connections") — always visible as drop target
                let unfoldered = viewModel.filteredConnections.filter { $0.folderId == nil }
                sectionHeader("All Connections", systemImage: "server.rack", color: .secondary)
                    .contentShape(Rectangle())
                    .onDrop(of: [.connection], delegate: ConnectionDropDelegate(
                        targetFolder: nil,
                        viewModel: viewModel
                    ))
                ForEach(unfoldered) { connection in
                    connectionRow(connection)
                }

                // Folder sections
                ForEach(viewModel.folders) { folder in
                    let folderConnections = viewModel.filteredConnections.filter { $0.folderId == folder.id }

                    sectionHeader(folder.name, systemImage: "folder", color: .secondary)
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

                    if folderConnections.isEmpty {
                        Text("No connections")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 16)
                            .padding(.vertical, 2)
                    } else {
                        ForEach(folderConnections) { connection in
                            connectionRow(connection)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.return) {
            if let connection = viewModel.selectedConnection {
                viewModel.connectToServer(connection)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) {
            viewModel.selectAdjacentConnection(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectAdjacentConnection(direction: 1)
            return .handled
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            // MARK: Accessibility (A11Y-03) — section headers are landmarks.
            // .isHeader lets VoiceOver users landmark-jump Recent → Favorites
            // → All Connections → folder headers (VO+Cmd+H).
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }

    // MARK: - Connection Row

    @ViewBuilder
    private func connectionRow(_ connection: Connection) -> some View {
        let isSelected = viewModel.selectedConnectionId == connection.id
        ConnectionRowView(
            connection: connection,
            connectionStatus: viewModel.connectionStatuses[connection.id],
            isSelected: isSelected
        )
        .onTapGesture(count: 2) {
            viewModel.connectToServer(connection)
        }
        .onTapGesture {
            viewModel.selectedConnectionId = connection.id
        }
        .onDrag {
            connection.toNSItemProvider()
        }
        .accessibilityIdentifier("connectionRow_\(connection.name)")
        // MARK: Accessibility (criterion #4) — pointer-free custom actions.
        // Every context-menu operation below gets an equivalent
        // .accessibilityAction(named:) so VoiceOver users reach them via the
        // Actions menu (VO+Cmd+Space) without a mouse right-click. Each action
        // invokes the EXACT SAME viewModel.* method as its context-menu
        // counterpart — no parallel logic, no drift (T-4-06).
        .accessibilityAction(named: "Connect") {
            viewModel.connectToServer(connection)
        }
        .accessibilityAction(named: "Open Terminal") {
            viewModel.requestTerminal(for: connection)
        }
        .accessibilityAction(named: "Edit") {
            viewModel.editConnection(connection)
        }
        .accessibilityAction(named: "Duplicate") {
            Task { await viewModel.duplicateConnection(connection) }
        }
        .accessibilityAction(named: connection.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            Task { await viewModel.toggleFavorite(connection) }
        }
        .accessibilityAction(named: "Delete") {
            Task { await viewModel.deleteConnection(connection) }
        }
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

                Button {
                    Task {
                        await viewModel.toggleFavorite(connection)
                    }
                } label: {
                    Label(connection.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: connection.isFavorite ? "star.slash" : "star")
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
