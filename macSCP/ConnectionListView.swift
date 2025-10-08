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

                    Button(action: { showingNewFolderSheet = true }) {
                        Label("Create New Folder", systemImage: "plus.circle.fill")
                            .font(.body)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(folder.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingNewConnectionSheet = true }) {
                    Label("New Connection", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // Connections grid
            if folder.connections.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "network.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No connections in this folder")
                        .foregroundColor(.secondary)
                        .padding()
                    Button("Add Connection") {
                        showingNewConnectionSheet = true
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
                    ], spacing: 20) {
                        ForEach(folder.connections) { connection in
                            ConnectionCardView(
                                connection: connection,
                                isSelected: selectedConnectionId == connection.id,
                                isHovered: hoveredConnectionId == connection.id
                            )
                            .onTapGesture {
                                withAnimation(.none) {
                                    selectedConnectionId = connection.id
                                    selectedConnection = connection
                                }
                            }
                            .onTapGesture(count: 2) {
                                selectedConnection = connection
                                showingPasswordPrompt = true
                            }
                            .onHover { isHovering in
                                hoveredConnectionId = isHovering ? connection.id : nil
                            }
                            .contextMenu {
                                Button(action: {
                                    selectedConnection = connection
                                    showingPasswordPrompt = true
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
                                    deleteConnection(connection)
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

struct ConnectionCardView: View {
    let connection: SSHConnection
    var isSelected: Bool = false
    var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .blue)
                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }

            Text(connection.name)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                    Text(connection.host)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person")
                        .font(.caption)
                    Text(connection.username)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isSelected ? Color.accentColor : (isHovered ? Color(.controlBackgroundColor).opacity(0.7) : Color(.controlBackgroundColor))
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 2)
    }
}

struct NewFolderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var folderName: String
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Folder")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Create a folder to organize your connections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Folder Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Production Servers", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onCreate()
                        }
                    }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Folder") {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 450, height: 260)
    }
}

struct NewConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let folder: ConnectionFolder?

    @State private var connectionName = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""

    var body: some View {
        Form {
            Section("Connection Details") {
                TextField("Connection Name", text: $connectionName)
                    .textFieldStyle(.roundedBorder)

                TextField("Host", text: $host)
                    .textFieldStyle(.roundedBorder)

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        saveConnection()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(connectionName.isEmpty || host.isEmpty || username.isEmpty)

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
        .navigationTitle("New Connection")
    }

    private func saveConnection() {
        guard let portNumber = Int(port) else { return }

        let connection = SSHConnection(
            name: connectionName,
            host: host,
            port: portNumber,
            username: username,
            folder: folder
        )

        modelContext.insert(connection)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save connection: \(error)")
        }

        dismiss()
    }
}

struct PasswordPromptForWindowView: View {
    @Environment(\.dismiss) private var dismiss
    let connection: SSHConnection
    let onConnect: (String) -> Void

    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text("Connect to \(connection.name)")
                    .font(.headline)

                Text("\(connection.username)@\(connection.host):\(connection.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    connect()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Connect") {
                    connect()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 400, height: 280)
    }

    private func connect() {
        onConnect(password)
        dismiss()
    }
}

#Preview {
    ConnectionListView()
        .modelContainer(for: [ConnectionFolder.self, SSHConnection.self], inMemory: true)
}
