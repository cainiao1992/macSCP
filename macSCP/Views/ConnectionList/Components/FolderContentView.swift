//
//  FolderContentView.swift
//  macSCP
//
//  Main content view showing connections in a folder
//

import SwiftUI
import SwiftData

struct FolderContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    @Bindable var folder: ConnectionFolder

    @State private var showingNewConnectionSheet = false
    @State private var selectedConnection: SSHConnection?
    @State private var showingPasswordPrompt = false
    @State private var hoveredConnection: SSHConnection?
    @State private var selectedConnectionId: UUID?
    @State private var hoveredConnectionId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            FolderHeaderView(
                folderName: folder.name,
                onAddConnection: { showingNewConnectionSheet = true }
            )

            Divider()

            // Connections grid
            if folder.connections.isEmpty {
                EmptyFolderView(onAddConnection: { showingNewConnectionSheet = true })
            } else {
                ConnectionsGridView(
                    connections: folder.connections,
                    selectedConnectionId: $selectedConnectionId,
                    hoveredConnectionId: $hoveredConnectionId,
                    onSelect: { connection in
                        selectedConnectionId = connection.id
                        selectedConnection = connection
                    },
                    onConnect: { connection in
                        selectedConnection = connection
                        showingPasswordPrompt = true
                    },
                    onDelete: deleteConnection
                )
            }
        }
        .sheet(isPresented: $showingNewConnectionSheet) {
            NewConnectionSheetView(folder: folder)
        }
        .sheet(isPresented: $showingPasswordPrompt) {
            if let connection = selectedConnection {
                PasswordPromptForWindowView(
                    connection: connection,
                    onConnect: { password in
                        openConnectionWindow(connection: connection, password: password)
                    }
                )
            }
        }
    }

    private func openConnectionWindow(connection: SSHConnection, password: String) {
        // Store connection info in UserDefaults temporarily for the new window
        let connectionInfo: [String: Any] = [
            "id": connection.id.uuidString,
            "name": connection.name,
            "host": connection.host,
            "port": connection.port,
            "username": connection.username,
            "password": password
        ]

        UserDefaults.standard.set(connectionInfo, forKey: "pendingConnection_\(connection.id.uuidString)")

        // Open window immediately
        openWindow(id: "ssh-explorer", value: connection.id.uuidString)
        showingPasswordPrompt = false
    }

    private func deleteConnection(_ connection: SSHConnection) {
        modelContext.delete(connection)
    }
}

// MARK: - Folder Header
struct FolderHeaderView: View {
    let folderName: String
    let onAddConnection: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            Text(folderName)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onAddConnection) {
                Label("New Connection", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Connections Grid
struct ConnectionsGridView: View {
    let connections: [SSHConnection]
    @Binding var selectedConnectionId: UUID?
    @Binding var hoveredConnectionId: UUID?
    let onSelect: (SSHConnection) -> Void
    let onConnect: (SSHConnection) -> Void
    let onDelete: (SSHConnection) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
            ], spacing: 20) {
                ForEach(connections) { connection in
                    ConnectionCardView(
                        connection: connection,
                        isSelected: selectedConnectionId == connection.id,
                        isHovered: hoveredConnectionId == connection.id
                    )
                    .onTapGesture {
                        withAnimation(.none) {
                            onSelect(connection)
                        }
                    }
                    .onTapGesture(count: 2) {
                        onConnect(connection)
                    }
                    .onHover { isHovering in
                        hoveredConnectionId = isHovering ? connection.id : nil
                    }
                    .contextMenu {
                        Button(action: {
                            onConnect(connection)
                        }) {
                            Label("Connect", systemImage: "arrow.right.circle.fill")
                        }

                        Divider()

                        Button(action: {
                            // Edit connection - you can implement this later
                        }) {
                            Label("Edit Connection", systemImage: "pencil")
                        }

                        Button(action: {
                            // Duplicate connection
                        }) {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            onDelete(connection)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
