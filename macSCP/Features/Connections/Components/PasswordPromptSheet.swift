//
//  PasswordPromptSheet.swift
//  macSCP
//
//  Password prompt for connecting to a server
//

import SwiftUI

struct PasswordPromptSheet: View {
    let connection: Connection
    var connectionError: AppError?
    var isConnecting: Bool = false
    let onConnect: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @FocusState private var isFocused: Bool

    private var promptTitle: String {
        switch connection.authMethod {
        case .privateKey:
            return "Enter Passphrase"
        default:
            return "Enter Password"
        }
    }

    private var fieldPlaceholder: String {
        switch connection.authMethod {
        case .privateKey:
            return "Private Key Passphrase (optional)"
        default:
            return "Password"
        }
    }

    var body: some View {
        VStack(spacing: UIConstants.spacing) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(promptTitle)
                .font(.headline)

            // Server context card (PASS-01)
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name)
                    .font(.headline)
                if connection.isSFTPConnection {
                    Text("\(connection.host):\(connection.port)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(connection.username)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            SecureField(fieldPlaceholder, text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    if !password.isEmpty || connection.authMethod == .privateKey {
                        onConnect(password)
                    }
                }

            // Error display (PASS-02)
            if let err = connectionError {
                Text(err.errorDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Connect") {
                    onConnect(password)
                }
                .keyboardShortcut(.defaultAction)
                .disabled((password.isEmpty && connection.authMethod != .privateKey) || isConnecting)
            }
        }
        .padding(UIConstants.spacing * 2)
        .frame(width: 300)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    PasswordPromptSheet(
        connection: Connection(
            name: "Production Server",
            host: "example.com",
            username: "admin"
        ),
        onConnect: { _ in },
        onCancel: {}
    )
}
