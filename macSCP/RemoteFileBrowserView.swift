//
//  RemoteFileBrowserView.swift
//  macSCP
//
//  File browser for remote SSH server
//

import SwiftUI

struct RemoteFileBrowserView: View {
    @ObservedObject var sshManager: SSHManager

    let host: String
    let port: Int
    let username: String
    let password: String

    var body: some View {
        VStack(spacing: 0) {
            // Header with connection status and current path
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(sshManager.connectionStatus, systemImage: sshManager.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(sshManager.isConnected ? .green : .red)

                    Spacer()

                    Button("Disconnect") {
                        sshManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!sshManager.isConnected)
                }

                HStack {
                    Image(systemName: "folder")
                    Text(sshManager.currentPath)
                        .font(.system(.body, design: .monospaced))
                    Spacer()

                    Button(action: {
                        Task {
                            try? await sshManager.listFiles(
                                host: host,
                                port: port,
                                username: username,
                                password: password,
                                path: sshManager.currentPath
                            )
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // File list
            if sshManager.isConnected {
                if sshManager.remoteFiles.isEmpty {
                    VStack {
                        Spacer()
                        Text("No files in this directory")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        // Parent directory navigation
                        if sshManager.currentPath != "/" {
                            Button(action: {
                                navigateToParent()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.turn.up.left")
                                        .foregroundColor(.blue)
                                    Text("..")
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                }
                            }
                        }

                        ForEach(sshManager.remoteFiles) { file in
                            FileRowView(file: file) {
                                if file.isDirectory {
                                    navigateToDirectory(file.path)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Not connected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func navigateToDirectory(_ path: String) {
        Task {
            do {
                try await sshManager.changeDirectory(
                    host: host,
                    port: port,
                    username: username,
                    password: password,
                    to: path
                )
            } catch {
                print("Failed to navigate: \(error)")
            }
        }
    }

    private func navigateToParent() {
        let parentPath: String
        if sshManager.currentPath == "/" {
            return
        }

        let components = sshManager.currentPath.split(separator: "/")
        if components.count <= 1 {
            parentPath = "/"
        } else {
            parentPath = "/" + components.dropLast().joined(separator: "/")
        }

        navigateToDirectory(parentPath)
    }
}

struct FileRowView: View {
    let file: RemoteFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(file.isDirectory ? .blue : .gray)
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(file.name)
                        .font(.system(.body, design: .monospaced))

                    Text(file.permissions)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(file.displaySize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RemoteFileBrowserView(
        sshManager: SSHManager(),
        host: "example.com",
        port: 22,
        username: "user",
        password: "pass"
    )
}
