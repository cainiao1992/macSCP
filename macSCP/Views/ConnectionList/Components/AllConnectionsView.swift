//
//  AllConnectionsView.swift
//  macSCP
//
//  View displaying all connections across all folders
//

import SwiftUI
import SwiftData

struct AllConnectionsView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext

    let allConnections: [SSHConnection]

    @State private var showingNewConnectionSheet = false
    @State private var selectedConnectionId: UUID?
    @State private var showingPasswordPrompt = false
    @State private var connectionToEdit: SSHConnection?
    @State private var showingDeleteConfirmation = false
    @State private var connectionToDelete: SSHConnection?

    private var selectedConnection: SSHConnection? {
        allConnections.first(where: { $0.id == selectedConnectionId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Connections grid
            if allConnections.isEmpty {
                EmptyAllConnectionsView(onAddConnection: { showingNewConnectionSheet = true })
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 320, maximum: 450), spacing: 16)
                    ], spacing: 16) {
                        ForEach(allConnections) { connection in
                            Button(action: {
                                selectedConnectionId = connection.id
                            }) {
                                ConnectionCardView(
                                    connection: connection,
                                    isSelected: selectedConnectionId == connection.id
                                )
                            }
                            .buttonStyle(.plain)
                            .onTapGesture(count: 2) {
                                handleConnect(connection)
                            }
                            .contextMenu {
                                Button(action: {
                                    selectedConnectionId = connection.id
                                    handleConnect(connection)
                                }) {
                                    Label("Connect", systemImage: "arrow.right.circle.fill")
                                }

                                Divider()

                                Button(action: {
                                    connectionToEdit = connection
                                }) {
                                    Label("Edit Connection", systemImage: "pencil")
                                }

                                Button(action: {
                                    duplicateConnection(connection)
                                }) {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    connectionToDelete = connection
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .contentMargins(.all, 0, for: .scrollContent)
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
            NewConnectionSheetView(folder: nil)
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
        .sheet(item: $connectionToEdit) { connection in
            EditConnectionSheetView(connection: connection)
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
                description: connection.displayDescription.isEmpty ? nil : connection.displayDescription,
                tags: connection.connectionTags.isEmpty ? nil : connection.connectionTags,
                iconName: connection.iconName,
                folder: connection.folder
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

// MARK: - Empty State
struct EmptyAllConnectionsView: View {
    let onAddConnection: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Connections")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first SSH connection to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onAddConnection) {
                Label("Create New Connection", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
