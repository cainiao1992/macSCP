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
    @State private var hasStoredPassword = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: connection.authType == .key ? "key.fill" : "lock.shield")
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

            if connection.authType == .password {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if hasStoredPassword {
                            Text("(saved)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    SecureField(hasStoredPassword ? "Using saved password" : "Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(hasStoredPassword)
                        .onSubmit {
                            if !password.isEmpty || hasStoredPassword {
                                connect()
                            }
                        }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Using SSH key authentication")
                            .font(.subheadline)
                    }

                    Text(connection.privateKeyPath ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
                .disabled(connection.authType == .password && password.isEmpty && !hasStoredPassword)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 450, height: 260)
        .onAppear {
            loadStoredPassword()
        }
    }

    private func loadStoredPassword() {
        // Only try to load password if authentication type is password and savePassword is true
        if connection.authType == .password && connection.shouldSavePassword {
            if let storedPassword = KeychainManager.shared.getPassword(for: connection.id.uuidString) {
                password = storedPassword
                hasStoredPassword = true
            }
        }
    }

    private func connect() {
        // For key-based authentication, pass empty string (not used)
        let authPassword = connection.authType == .key ? "" : password
        onConnect(authPassword)
        dismiss()
    }
}
