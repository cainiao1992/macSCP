//
//  ConnectionListColumn.swift
//  macSCP
//
//  List view displaying connections for the middle column (Apple Notes style)
//

import SwiftUI

struct ConnectionListColumn: View {
    @Bindable var viewModel: ConnectionListViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Loading connections...")

            case .success:
                if viewModel.filteredConnections.isEmpty {
                    emptyStateView
                } else {
                    connectionList
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
        .navigationTitle(listTitle)
        .navigationSubtitle("\(viewModel.filteredConnections.count) connections")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let connection = viewModel.selectedConnection {
                        viewModel.connectToServer(connection)
                    }
                } label: {
                    Label("Open Connection", systemImage: "arrow.right.square")
                }
                .help("Open selected connection")
                .disabled(viewModel.selectedConnection == nil)

                Button {
                    viewModel.isShowingNewConnectionSheet = true
                } label: {
                    Label("New Connection", systemImage: "square.and.pencil")
                }
                .help("New Connection")
                .accessibilityIdentifier("newConnectionButton")
            }
        }
    }

    private var listTitle: String {
        switch viewModel.selectedSidebarItem {
        case .allConnections:
            return "All Connections"
        case .folder(let id):
            return viewModel.folders.first { $0.id == id }?.name ?? "Folder"
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if viewModel.searchText.isEmpty {
            switch viewModel.selectedSidebarItem {
            case .allConnections:
                EmptyStateView(
                    icon: "server.rack",
                    title: "No Connections",
                    message: "Add a new SSH connection to get started\nwith remote file management.",
                    actionTitle: "Add Connection"
                ) {
                    viewModel.isShowingNewConnectionSheet = true
                }
            case .folder:
                EmptyStateView(
                    icon: "folder",
                    title: "Empty Folder",
                    message: "This folder has no connections.\nDrag connections here or create a new one.",
                    actionTitle: "Add Connection"
                ) {
                    viewModel.isShowingNewConnectionSheet = true
                }
            }
        } else {
            EmptyStateView.noSearchResults
        }
    }

    // NOTE: ScrollView refactor lost List's native .swipeActions support (HI-04).
    // Delete is currently available via context menu (right-click) and keyboard
    // (Delete key / .onDeleteCommand). Restoring swipe-to-delete requires either:
    // 1. Custom DragGesture with offset animation and threshold detection, or
    // 2. Reverting to List with custom row styling for selection highlighting.
    // This needs a design decision on the List vs ScrollView trade-off.
    private var connectionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.filteredConnections) { connection in
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
                    .draggable(connection)
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
        .onDeleteCommand {
            if let connection = viewModel.selectedConnection {
                Task { await viewModel.deleteConnection(connection) }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ConnectionListColumn(viewModel: DependencyContainer.shared.makeConnectionListViewModel())
}
