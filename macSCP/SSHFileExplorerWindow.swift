//
//  SSHFileExplorerWindow.swift
//  macSCP
//
//  Separate window for SSH file explorer
//

import SwiftUI

struct SSHFileExplorerWindow: View {
    let connectionId: String

    @StateObject private var sshManager = CitadelSFTPManager()
    @State private var connectionInfo: ConnectionInfo?
    @State private var isConnecting = true
    @State private var connectionError: String?

    struct ConnectionInfo {
        let name: String
        let host: String
        let port: Int
        let username: String
        let password: String
    }

    var body: some View {
        Group {
            if isConnecting {
                VStack {
                    ProgressView("Connecting...")
                        .padding()
                }
            } else if let error = connectionError {
                VStack(spacing: 20) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Connection Failed")
                        .font(.title2)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let info = connectionInfo, sshManager.isConnected {
                FinderStyleBrowserView(
                    sshManager: sshManager,
                    host: info.host,
                    port: info.port,
                    username: info.username,
                    password: info.password
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            loadConnectionAndConnect()
        }
        .onDisappear {
            Task {
                await sshManager.disconnect()
            }
            // Clean up stored connection info
            UserDefaults.standard.removeObject(forKey: "pendingConnection_\(connectionId)")
        }
    }

    private func loadConnectionAndConnect() {
        print("🔍 Loading connection info for ID: \(connectionId)")

        guard let storedInfo = UserDefaults.standard.dictionary(forKey: "pendingConnection_\(connectionId)") else {
            print("❌ No stored connection info found")
            connectionError = "Failed to load connection information. Please try connecting again."
            isConnecting = false
            return
        }

        print("✅ Found stored connection info: \(storedInfo.keys)")

        guard let name = storedInfo["name"] as? String,
              let host = storedInfo["host"] as? String,
              let port = storedInfo["port"] as? Int,
              let username = storedInfo["username"] as? String,
              let password = storedInfo["password"] as? String else {
            print("❌ Connection info incomplete")
            connectionError = "Connection information is incomplete"
            isConnecting = false
            return
        }

        print("📋 Connection details: \(username)@\(host):\(port)")

        let info = ConnectionInfo(name: name, host: host, port: port, username: username, password: password)
        connectionInfo = info

        Task {
            do {
                try await sshManager.connect(
                    host: host,
                    port: port,
                    username: username,
                    password: password
                )
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                print("❌ Connection failed: \(error)")
                await MainActor.run {
                    connectionError = error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }
}

#Preview {
    SSHFileExplorerWindow(connectionId: "test-id")
}
