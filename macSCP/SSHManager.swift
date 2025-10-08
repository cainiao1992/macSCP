//
//  SSHManager.swift
//  macSCP
//
//  SSH Manager for handling SSH connections and operations
//

import Foundation
import Combine

@MainActor
class SSHManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var remoteFiles: [RemoteFile] = []
    @Published var currentPath = "/"
    @Published var errorMessage: String?

    private var process: Process?

    func connect(host: String, port: Int, username: String, password: String) async throws {
        connectionStatus = "Connecting..."

        // For now, we'll use a simple SSH command approach
        // In a production app, you'd want to use a proper SSH library

        // Test connection using ssh command
        let testCommand = "exit"
        let result = try await executeSSHCommand(
            host: host,
            port: port,
            username: username,
            password: password,
            command: testCommand
        )

        isConnected = true
        connectionStatus = "Connected to \(username)@\(host)"

        // Load initial directory listing
        try await listFiles(host: host, port: port, username: username, password: password, path: currentPath)
    }

    func disconnect() {
        isConnected = false
        connectionStatus = "Disconnected"
        remoteFiles = []
        currentPath = "/"
        process?.terminate()
        process = nil
    }

    func listFiles(host: String, port: Int, username: String, password: String, path: String) async throws {
        currentPath = path

        // Use SSH to list files with details
        let command = "ls -la '\(path)' 2>/dev/null || ls -la ~"
        let output = try await executeSSHCommand(
            host: host,
            port: port,
            username: username,
            password: password,
            command: command
        )

        // Parse the output
        remoteFiles = parseFileList(output, basePath: path)
    }

    func changeDirectory(host: String, port: Int, username: String, password: String, to path: String) async throws {
        try await listFiles(host: host, port: port, username: username, password: password, path: path)
    }

    private func executeSSHCommand(host: String, port: Int, username: String, password: String, command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create expect script for password authentication
                let expectScript = """
                #!/usr/bin/expect -f
                set timeout 30
                spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p \(port) \(username)@\(host) "\(command)"
                expect {
                    "password:" {
                        send "\(password)\\r"
                        expect eof
                    }
                    "Permission denied" {
                        exit 1
                    }
                    eof
                }
                """

                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                let inputPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
                process.arguments = ["-c", expectScript]

                process.standardOutput = outputPipe
                process.standardError = errorPipe
                process.standardInput = inputPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    var output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 || !output.isEmpty {
                        // Clean up SSH warnings from output
                        output = output.components(separatedBy: .newlines)
                            .filter { !$0.contains("Warning:") && !$0.contains("Offending") }
                            .joined(separator: "\n")
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: SSHError.commandFailed(error.isEmpty ? "Connection failed" : error))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func parseFileList(_ output: String, basePath: String) -> [RemoteFile] {
        var files: [RemoteFile] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Skip empty lines and total line
            guard !line.isEmpty, !line.hasPrefix("total") else { continue }

            // Parse ls -la output
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 9 else { continue }

            let permissions = components[0]
            let size = Int64(components[4]) ?? 0
            let name = components[8...].joined(separator: " ")

            // Skip . and ..
            guard name != ".", name != ".." else { continue }

            let isDirectory = permissions.hasPrefix("d")
            let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"

            let file = RemoteFile(
                name: name,
                path: fullPath,
                isDirectory: isDirectory,
                size: size,
                permissions: permissions,
                modificationDate: nil
            )

            files.append(file)
        }

        return files.sorted { file1, file2 in
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }
            return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
        }
    }
}

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case commandFailed(String)
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}
