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
    @State private var showingEditSheet = false
    @State private var connectionToEdit: SSHConnection?
    @State private var showingDeleteConfirmation = false
    @State private var connectionToDelete: SSHConnection?
    @State private var hoveredConnection: SSHConnection?
    @State private var selectedConnectionId: UUID?
    @State private var hoveredConnectionId: UUID?

    var body: some View {
        VStack(spacing: 0) {
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
                        handleConnect(connection)
                    },
                    onEdit: { connection in
                        connectionToEdit = connection
                        showingEditSheet = true
                    },
                    onDuplicate: { connection in
                        duplicateConnection(connection)
                    },
                    onDelete: { connection in
                        connectionToDelete = connection
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingNewConnectionSheet = true }) {
                    Label("New Connection", systemImage: "plus")
                }
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
        .sheet(isPresented: $showingEditSheet) {
            if let connection = connectionToEdit {
                EditConnectionSheetView(connection: connection)
            }
        }
        .alert("Delete Connection", isPresented: $showingDeleteConfirmation, presenting: connectionToDelete) { connection in
            Button("Cancel", role: .cancel) {
                connectionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteConnection(connection)
            }
        } message: { connection in
            Text("Are you sure you want to delete '\(connection.name)'? This action cannot be undone.")
        }
    }

    private func handleConnect(_ connection: SSHConnection) {
        // Check if we have a saved password or using SSH key
        if connection.authType == .key {
            // SSH key authentication - no password needed
            openConnectionWindow(connection: connection, password: "")
        } else if connection.shouldSavePassword {
            // Try to get saved password from keychain
            if let savedPassword = KeychainManager.shared.getPassword(for: connection.id.uuidString) {
                // Use saved password directly
                openConnectionWindow(connection: connection, password: savedPassword)
            } else {
                // Saved password flag is set but password not found - show prompt
                showingPasswordPrompt = true
            }
        } else {
            // No saved password - show prompt
            showingPasswordPrompt = true
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

    private func duplicateConnection(_ connection: SSHConnection) {
        withAnimation {
            // Create a new connection with the same properties
            let duplicatedConnection = SSHConnection(
                name: "\(connection.name) Copy",
                host: connection.host,
                port: connection.port,
                username: connection.username,
                authenticationType: connection.authType,
                privateKeyPath: connection.privateKeyPath,
                savePassword: connection.shouldSavePassword,
                folder: folder
            )

            modelContext.insert(duplicatedConnection)

            // Copy password from keychain if it exists
            if connection.shouldSavePassword {
                if let savedPassword = KeychainManager.shared.getPassword(for: connection.id.uuidString) {
                    _ = KeychainManager.shared.savePassword(savedPassword, for: duplicatedConnection.id.uuidString)
                }
            }

            // Save changes immediately
            do {
                try modelContext.save()
            } catch {
                print("Failed to duplicate connection: \(error)")
            }
        }
    }

    private func deleteConnection(_ connection: SSHConnection) {
        withAnimation {
            // Delete saved password from keychain if it exists
            if connection.shouldSavePassword {
                _ = KeychainManager.shared.deletePassword(for: connection.id.uuidString)
            }

            // Clear selection if deleting the selected connection
            if selectedConnectionId == connection.id {
                selectedConnectionId = nil
                selectedConnection = nil
            }

            // Delete the connection
            modelContext.delete(connection)

            // Save changes immediately
            do {
                try modelContext.save()
            } catch {
                print("Failed to delete connection: \(error)")
            }

            connectionToDelete = nil
        }
    }
}

// MARK: - Connections Grid
struct ConnectionsGridView: View {
    let connections: [SSHConnection]
    @Binding var selectedConnectionId: UUID?
    @Binding var hoveredConnectionId: UUID?
    let onSelect: (SSHConnection) -> Void
    let onConnect: (SSHConnection) -> Void
    let onEdit: (SSHConnection) -> Void
    let onDuplicate: (SSHConnection) -> Void
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
                            onEdit(connection)
                        }) {
                            Label("Edit Connection", systemImage: "pencil")
                        }

                        Button(action: {
                            onDuplicate(connection)
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
            .padding(12)
        }
        .contentMargins(.all, 0, for: .scrollContent)
    }
}
