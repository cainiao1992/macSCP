//
//  SFTPManager.swift
//  macSCP
//
//  SFTP-based file manager for better file operations
//

import Foundation
import Combine

@MainActor
class SFTPManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var remoteFiles: [RemoteFile] = []
    @Published var currentPath = "/"
    @Published var errorMessage: String?

    private var process: Process?

    func connect(host: String, port: Int, username: String, password: String) async throws {
        connectionStatus = "Connecting..."

        // Test connection
        let testCommand = "echo 'connected'"
        _ = try await executeSSHCommand(
            host: host,
            port: port,
            username: username,
            password: password,
            command: testCommand
        )

        isConnected = true
        connectionStatus = "Connected to \(username)@\(host)"

        // Load initial directory listing using SFTP
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

        // Use SFTP for file listing - more reliable and structured than ls
        let sftpScript = """
        cd '\(path)' 2>/dev/null || cd ~
        pwd
        ls -1
        """

        let expectScript = """
        #!/usr/bin/expect -f
        set timeout 30
        log_user 0
        spawn sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P \(port) \(username)@\(host)
        expect {
            "password:" {
                send "\(password)\\r"
                exp_continue
            }
            "sftp>" {
                send "cd '\(path)'\\r"
                expect "sftp>"
                send "pwd\\r"
                expect -re "Remote working directory: (.*)"
                set pwd $expect_out(1,string)
                puts "PWD:$pwd"
                send "ls -la\\r"
                expect "sftp>"
                puts $expect_out(buffer)
                send "quit\\r"
            }
            "Permission denied" {
                exit 1
            }
            timeout {
                exit 1
            }
        }
        expect eof
        """

        let output = try await executeSFTPCommand(
            host: host,
            port: port,
            username: username,
            password: password,
            script: expectScript
        )

        // Parse SFTP output
        remoteFiles = parseSFTPOutput(output, basePath: path)
    }

    func changeDirectory(host: String, port: Int, username: String, password: String, to path: String) async throws {
        try await listFiles(host: host, port: port, username: username, password: password, path: path)
    }

    private func executeSFTPCommand(host: String, port: Int, username: String, password: String, script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
                process.arguments = ["-c", script]

                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    var output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 || !output.isEmpty {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: SSHError.commandFailed(error.isEmpty ? "SFTP command failed" : error))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func executeSSHCommand(host: String, port: Int, username: String, password: String, command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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

                process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
                process.arguments = ["-c", expectScript]

                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    var output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    if process.terminationStatus == 0 || !output.isEmpty {
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

    private func parseSFTPOutput(_ output: String, basePath: String) -> [RemoteFile] {
        var files: [RemoteFile] = []
        let lines = output.components(separatedBy: .newlines)

        // Find the actual file listing part
        var inFileList = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip until we find the ls -la output
            if trimmed.hasPrefix("drwx") || trimmed.hasPrefix("-rw") || trimmed.hasPrefix("lrwx") {
                inFileList = true
            }

            if !inFileList || trimmed.isEmpty {
                continue
            }

            // Parse SFTP ls -la output (similar to regular ls -la)
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 9 else { continue }

            let permissions = components[0]
            let sizeStr = components[4]
            let name = components[8...].joined(separator: " ")

            // Skip . and ..
            guard name != ".", name != ".." else { continue }

            let isDirectory = permissions.hasPrefix("d")
            let size = Int64(sizeStr) ?? 0
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
