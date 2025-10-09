//
//  PasswordPromptView.swift
//  macSCP
//
//  Password prompt for connecting to saved SSH connections
//

import SwiftUI

struct PasswordPromptView: View {
    @Environment(\.dismiss) private var dismiss
    let connection: SSHConnection
    @Binding var password: String
    let onConnect: (String) -> Void

    @State private var isConnecting = false

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
    }

    private func connect() {
        isConnecting = true
        onConnect(password)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isConnecting = false
        }
    }
}

#Preview {
    PasswordPromptView(
        connection: SSHConnection(name: "Test Server", host: "localhost", port: 2222, username: "testuser"),
        password: .constant(""),
        onConnect: { _ in }
    )
}
