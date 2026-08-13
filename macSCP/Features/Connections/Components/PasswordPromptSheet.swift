//
//  PasswordPromptSheet.swift
//  macSCP
//
//  Password prompt for connecting to a server
//

import SwiftUI

struct PasswordPromptSheet: View {
    let connectionName: String
    let authMethod: AuthMethod
    let onConnect: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""
    @FocusState private var isFocused: Bool

    private var promptTitle: String {
        switch authMethod {
        case .privateKey:
            return "Enter Passphrase"
        default:
            return "Enter Password"
        }
    }

    private var promptDescription: String {
        switch authMethod {
        case .privateKey:
            return "Enter the passphrase for the private key of \"\(connectionName)\""
        default:
            return "Enter the password for \"\(connectionName)\""
        }
    }

    private var fieldPlaceholder: String {
        switch authMethod {
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

            Text(promptDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField(fieldPlaceholder, text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    if !password.isEmpty || authMethod == .privateKey {
                        onConnect(password)
                    }
                }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Connect") {
                    onConnect(password)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty && authMethod != .privateKey)
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
        connectionName: "Production Server",
        authMethod: .password,
        onConnect: { _ in },
        onCancel: {}
    )
}
