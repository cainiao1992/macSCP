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
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect to \(connection.name)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(connection.username)@\(connection.host):\(connection.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !password.isEmpty {
                            connect()
                        }
                    }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Connect") {
                    connect()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 450, height: 260)
    }

    private func connect() {
        onConnect(password)
        dismiss()
    }
}
