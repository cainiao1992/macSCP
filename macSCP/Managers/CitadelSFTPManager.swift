//
//  CitadelSFTPManager.swift
//  macSCP
//
//  Proper SFTP implementation using Citadel
//

import Foundation
import Combine
import Citadel
import NIO
import NIOCore
import NIOFoundationCompat
import Logging

enum SSHError: LocalizedError {
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return message
        }
    }
}

enum SFTPError: LocalizedError {
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let message):
            return message
        }
    }
}

// Helper functions outside of MainActor context
private func isDirectoryFromPermissions(_ permissions: UInt32?) -> Bool {
    guard let permissions = permissions else {
        return false
    }
    // Check if the file type bits indicate a directory (S_IFDIR = 0o040000)
    return (permissions & 0o170000) == 0o040000
}

private func formatPermissions(_ attributes: SFTPFileAttributes) -> String {
    guard let permissions = attributes.permissions else {
        return "----------"
    }

    var result = ""

    // File type - check the file type bits
    let fileType = permissions & 0o170000
    switch fileType {
    case 0o040000: // S_IFDIR
        result += "d"
    case 0o120000: // S_IFLNK
        result += "l"
    case 0o100000: // S_IFREG
        result += "-"
    case 0o060000: // S_IFBLK
        result += "b"
    case 0o020000: // S_IFCHR
        result += "c"
    case 0o010000: // S_IFIFO
        result += "p"
    case 0o140000: // S_IFSOCK
        result += "s"
    default:
        result += "-"
    }

    // Owner permissions
    result += (permissions & 0o400) != 0 ? "r" : "-"
    result += (permissions & 0o200) != 0 ? "w" : "-"
    result += (permissions & 0o100) != 0 ? "x" : "-"

    // Group permissions
    result += (permissions & 0o040) != 0 ? "r" : "-"
    result += (permissions & 0o020) != 0 ? "w" : "-"
    result += (permissions & 0o010) != 0 ? "x" : "-"

    // Other permissions
    result += (permissions & 0o004) != 0 ? "r" : "-"
    result += (permissions & 0o002) != 0 ? "w" : "-"
    result += (permissions & 0o001) != 0 ? "x" : "-"

    return result
}

@MainActor
class CitadelSFTPManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var remoteFiles: [RemoteFile] = []
    @Published var currentPath = "/"
    @Published var errorMessage: String?

    private var client: SSHClient?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?

    private var connectionInfo: (host: String, port: Int, username: String, password: String)?

    func connect(host: String, port: Int, username: String, password: String) async throws {
        connectionStatus = "Connecting..."

        // Store connection info for later use
        connectionInfo = (host, port, username, password)

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        eventLoopGroup = group

        do {
            // Normalize localhost to 127.0.0.1 to avoid IPv6 issues
            let normalizedHost = (host.lowercased() == "localhost") ? "127.0.0.1" : host

            print("🔌 Attempting to connect to \(username)@\(normalizedHost):\(port)")

            // Create SSH connection with proper configuration
            let authMethod: SSHAuthenticationMethod = .passwordBased(username: username, password: password)

            client = try await SSHClient.connect(
                host: normalizedHost,
                port: port,
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never,
                group: group
            )

            print("✅ SSH connection established")

            isConnected = true
            connectionStatus = "Connected to \(username)@\(host)"

            // Load initial directory
            print("📂 Loading initial directory...")
            try await listFiles(path: ".")

        } catch let error as NIOConnectionError {
            print("❌ Connection error: \(error)")
            try? await group.shutdownGracefully()
            eventLoopGroup = nil
            
            // Provide more specific error message based on the error description
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("connection refused") {
                throw SSHError.connectionFailed("Connection refused. Make sure the SSH server is running on \(host):\(port)")
            } else if errorDescription.contains("host unreachable") || errorDescription.contains("no route to host") {
                throw SSHError.connectionFailed("Host unreachable. Check the hostname and network connection.")
            } else if errorDescription.contains("timeout") {
                throw SSHError.connectionFailed("Connection timeout. The server may be slow or unreachable.")
            } else if errorDescription.contains("operation not permitted") {
                throw SSHError.connectionFailed("Operation not permitted. This could mean:\n• No SSH server is running on port \(port)\n• The port is blocked by a firewall\n• You don't have permission to connect to this port")
            } else {
                throw SSHError.connectionFailed("Connection error: \(error.localizedDescription)")
            }
        } catch {
            print("❌ SSH error: \(error)")
            try? await group.shutdownGracefully()
            eventLoopGroup = nil
            
            // Handle specific SSH/SFTP errors
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("authentication") || errorDescription.contains("password") {
                throw SSHError.connectionFailed("Authentication failed. Please check your username and password.")
            } else if errorDescription.contains("permission denied") {
                throw SSHError.connectionFailed("Permission denied. Please check your credentials.")
            } else if errorDescription.contains("operation not permitted") {
                throw SSHError.connectionFailed("Operation not permitted. This could mean:\n• No SSH server is running on port \(port)\n• The port is blocked by a firewall\n• You don't have permission to connect to this port")
            } else {
                throw SSHError.connectionFailed("Failed to connect: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() async {
        try? await client?.close()
        try? await eventLoopGroup?.shutdownGracefully()

        client = nil
        eventLoopGroup = nil

        isConnected = false
        connectionStatus = "Disconnected"
        remoteFiles = []
        currentPath = "/"
        connectionInfo = nil
    }

    func listFiles(path: String) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        // Capture current path before entering the closure
        let capturedCurrentPath = self.currentPath
        
        let result = try await client.withSFTP { sftp in
            // Update current path
            let actualPath: String
            if path == "~" {
                // Get home directory
                actualPath = try await sftp.getRealPath(atPath: ".")
            } else if path == "." {
                actualPath = capturedCurrentPath.isEmpty ? "/" : capturedCurrentPath
            } else if path == ".." {
                let components = capturedCurrentPath.split(separator: "/")
                if components.count > 1 {
                    actualPath = "/" + components.dropLast().joined(separator: "/")
                } else {
                    actualPath = "/"
                }
            } else {
                actualPath = path
            }

            // List directory contents
            let listing = try await sftp.listDirectory(atPath: actualPath)

            var files: [RemoteFile] = []

            for nameResponse in listing {
                for component in nameResponse.components {
                    // Skip . and ..
                    guard component.filename != ".", component.filename != ".." else { continue }

                    let fullPath = actualPath.hasSuffix("/")
                        ? "\(actualPath)\(component.filename)"
                        : "\(actualPath)/\(component.filename)"

                    let isDirectory = isDirectoryFromPermissions(component.attributes.permissions)
                    let size = Int64(component.attributes.size ?? 0)
                    let permissions = formatPermissions(component.attributes)
                    let modDate = component.attributes.accessModificationTime?.modificationTime

                    let file = RemoteFile(
                        name: component.filename,
                        path: fullPath,
                        isDirectory: isDirectory,
                        size: size,
                        permissions: permissions,
                        modificationDate: modDate
                    )

                    files.append(file)
                }
            }

            return (actualPath, files)
        }
        
        // Update properties on the main actor
        self.currentPath = result.0
        self.remoteFiles = result.1.sorted { file1, file2 in
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }
            return file1.name.localizedCaseInsensitiveCompare(file2.name) == .orderedAscending
        }
    }

    func changeDirectory(to path: String) async throws {
        try await listFiles(path: path)
    }

    func downloadFile(remotePath: String, to localURL: URL) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        try await client.withSFTP { sftp in
            try await sftp.withFile(filePath: remotePath, flags: .read) { file in
                let buffer = try await file.readAll()
                let data = Data(buffer: buffer)
                try data.write(to: localURL)
            }
        }
    }

    func uploadFile(localURL: URL, to remotePath: String) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        let data = try Data(contentsOf: localURL)

        do {
            try await client.withSFTP { sftp in
                // First try to remove the file if it exists
                try? await sftp.remove(at: remotePath)

                // Then create and write the new file
                try await sftp.withFile(filePath: remotePath, flags: [.write, .create, .truncate]) { file in
                    try await file.write(ByteBuffer(data: data))
                }
            }
        } catch {
            throw parseSFTPError(error, operation: "upload file")
        }
    }

    func createDirectory(path: String) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        do {
            try await client.withSFTP { sftp in
                try await sftp.createDirectory(atPath: path)
            }
        } catch {
            // Convert SFTP errors to more user-friendly messages
            throw parseSFTPError(error, operation: "create directory")
        }
    }

    private func parseSFTPError(_ error: Error, operation: String) -> Error {
        let errorString = String(describing: error)

        // Check for common SFTP error codes
        if errorString.contains("SSH_FX_PERMISSION_DENIED") || errorString.contains("Permission denied") {
            return SFTPError.operationFailed("Permission denied. You don't have permission to \(operation) at this location.")
        } else if errorString.contains("SSH_FX_NO_SUCH_FILE") || errorString.contains("No such file") {
            return SFTPError.operationFailed("Path not found. The file or folder doesn't exist.")
        } else if errorString.contains("SSH_FX_FILE_ALREADY_EXISTS") || errorString.contains("File already exists") {
            return SFTPError.operationFailed("A file or folder with this name already exists.")
        } else if errorString.contains("SSH_FX_FAILURE") {
            return SFTPError.operationFailed("Operation failed on the server. The folder may not be empty or you may not have the required permissions.")
        } else if errorString.contains("SSH_FX_BAD_MESSAGE") {
            return SFTPError.operationFailed("Invalid request. Please try again.")
        } else if errorString.contains("SSH_FX_NO_CONNECTION") {
            return SFTPError.operationFailed("Connection lost. Please reconnect and try again.")
        } else {
            return SFTPError.operationFailed("Failed to \(operation): \(error.localizedDescription)")
        }
    }

    func deleteFile(path: String, isDirectory: Bool = false) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        do {
            if isDirectory {
                // For directories, use rm -rf to recursively delete
                let result = try await client.executeCommand("rm -rf '\(path)'")
                let output = String(buffer: result)

                // Check for errors in stderr or output
                if !output.isEmpty {
                    let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedOutput.lowercased().contains("permission denied") {
                        throw SFTPError.operationFailed("Permission denied. You don't have permission to delete at this location.")
                    } else if trimmedOutput.lowercased().contains("no such file") {
                        throw SFTPError.operationFailed("Path not found. The folder doesn't exist.")
                    } else if !trimmedOutput.isEmpty {
                        throw SFTPError.operationFailed("Failed to delete: \(trimmedOutput)")
                    }
                }
            } else {
                // For files, use SFTP remove
                try await client.withSFTP { sftp in
                    try await sftp.remove(at: path)
                }
            }
        } catch let error as SFTPError {
            throw error
        } catch {
            throw parseSFTPError(error, operation: "delete")
        }
    }

    func renameFile(from oldPath: String, to newPath: String) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        do {
            try await client.withSFTP { sftp in
                try await sftp.rename(at: oldPath, to: newPath)
            }
        } catch {
            throw parseSFTPError(error, operation: "rename")
        }
    }

    func copyFile(from sourcePath: String, to destinationPath: String, isDirectory: Bool) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        do {
            // Use cp command to copy files/directories
            let command = isDirectory ? "cp -r '\(sourcePath)' '\(destinationPath)'" : "cp '\(sourcePath)' '\(destinationPath)'"
            let result = try await client.executeCommand(command)
            let output = String(buffer: result)

            // Check for errors
            if !output.isEmpty {
                let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedOutput.lowercased().contains("permission denied") {
                    throw SFTPError.operationFailed("Permission denied. You don't have permission to copy at this location.")
                } else if trimmedOutput.lowercased().contains("no such file") {
                    throw SFTPError.operationFailed("Source file or folder doesn't exist.")
                } else if !trimmedOutput.isEmpty {
                    throw SFTPError.operationFailed("Failed to copy: \(trimmedOutput)")
                }
            }
        } catch let error as SFTPError {
            throw error
        } catch {
            throw parseSFTPError(error, operation: "copy")
        }
    }

    func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        guard let client = client else {
            throw SSHError.connectionFailed("Not connected")
        }

        do {
            // Use mv command to move files/directories
            let command = "mv '\(sourcePath)' '\(destinationPath)'"
            let result = try await client.executeCommand(command)
            let output = String(buffer: result)

            // Check for errors
            if !output.isEmpty {
                let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedOutput.lowercased().contains("permission denied") {
                    throw SFTPError.operationFailed("Permission denied. You don't have permission to move at this location.")
                } else if trimmedOutput.lowercased().contains("no such file") {
                    throw SFTPError.operationFailed("Source file or folder doesn't exist.")
                } else if !trimmedOutput.isEmpty {
                    throw SFTPError.operationFailed("Failed to move: \(trimmedOutput)")
                }
            }
        } catch let error as SFTPError {
            throw error
        } catch {
            throw parseSFTPError(error, operation: "move")
        }
    }
}
