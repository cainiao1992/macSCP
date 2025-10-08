//
//  SSHConnectionView.swift
//  macSCP
//
//  UI for creating SSH connections
//

import SwiftUI
import SwiftData

struct SSHConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var sshManager: SSHManager

    @State private var connectionName = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var saveConnection = true

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

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Toggle("Save Connection", isOn: $saveConnection)
            }

            Section {
                HStack {
                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    if saveConnection {
                        Button("Save") {
                            saveAndClose()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(connectionName.isEmpty || host.isEmpty || username.isEmpty)
                    } else {
                        Button("Connect") {
                            connectToServer()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
                    }

                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .navigationTitle("New SSH Connection")
        .overlay {
            if isConnecting {
                VStack {
                    ProgressView("Connecting...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveAndClose() {
        guard let portNumber = Int(port) else {
            errorMessage = "Invalid port number"
            showError = true
            return
        }

        let connection = SSHConnection(
            name: connectionName,
            host: host,
            port: portNumber,
            username: username
        )

        modelContext.insert(connection)
        dismiss()
    }

    private func connectToServer() {
        guard let portNumber = Int(port) else {
            errorMessage = "Invalid port number"
            showError = true
            return
        }

        isConnecting = true

        Task {
            do {
                try await sshManager.connect(
                    host: host,
                    port: portNumber,
                    username: username,
                    password: password
                )
                await MainActor.run {
                    isConnecting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    SSHConnectionView(sshManager: SSHManager())
}
