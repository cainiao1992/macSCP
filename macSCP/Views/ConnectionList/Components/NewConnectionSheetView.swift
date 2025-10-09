//
//  NewConnectionSheetView.swift
//  macSCP
//
//  Sheet for creating a new SSH connection
//

import SwiftUI
import SwiftData

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
