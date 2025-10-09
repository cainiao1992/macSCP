//
//  PasswordPromptForWindowView.swift
//  macSCP
//
//  Password prompt for SSH connection
//

import SwiftUI

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
