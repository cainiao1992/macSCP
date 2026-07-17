//
//  SystemSFTPSession.swift
//  macSCP
//
//  SFTP session that uses system `ssh` and `scp` commands.
//  This allows RSA and ED25519 keys to work with modern OpenSSH 8.8+ servers
//  because the system ssh automatically negotiates the correct algorithms.
//
//  Operations are executed via individual ssh commands rather than
//  the binary SFTP protocol. This is less efficient but fully compatible.
//

import Foundation

actor SystemSFTPSession: SFTPSessionProtocol {
    private var host: String = ""
    private var port: Int = 22
    private var username: String = ""
    private var privateKeyPath: String = ""
    private(set) var isConnected = false
    private(set) var currentPath = "/"
    private var homePath = "/"
    private var password: String?
    private var askpassScriptPath: String?

    init() {}

    // MARK: - Connection

    func connect(host: String, port: Int, username: String, password: String) async throws {
        logInfo("System SFTP connecting to \(username)@\(host):\(port) via password", category: .sftp)

        self.host = host
        self.port = port
        self.username = username
        self.password = password

        let tempDir = NSTemporaryDirectory()
        let scriptPath = (tempDir as NSString).appendingPathComponent("macSCP-askpass-\(UUID().uuidString).sh")
        try writeAskpassScript(to: scriptPath)
        self.askpassScriptPath = scriptPath

        self.isConnected = true
        currentPath = try await executeSSHCommand("pwd")
        homePath = currentPath
        logInfo("System SFTP connected to \(host) via password auth", category: .sftp)
    }

    func connect(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String?) async throws {
        logInfo("System SFTP connecting to \(username)@\(host):\(port)", category: .sftp)

        self.host = host
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
        self.isConnected = true
        currentPath = try await executeSSHCommand("pwd")
        homePath = currentPath
        logInfo("System SFTP connected to \(host)", category: .sftp)
    }

    func disconnect() async {
        logInfo("System SFTP disconnecting", category: .sftp)

        if let path = askpassScriptPath {
            try? FileManager.default.removeItem(atPath: path)
            askpassScriptPath = nil
        }
        password = nil

        isConnected = false
        currentPath = "/"
        homePath = "/"
    }

    // MARK: - File Operations

    func listFiles(at path: String) async throws -> [RemoteFile] {
        let resolvedPath = resolvePath(path)
        currentPath = resolvedPath
        let output = try await executeSSHCommand("ls -la --time-style='+%Y-%m-%d %H:%M:%S' '\(escaped(resolvedPath))' 2>/dev/null || ls -la '\(escaped(resolvedPath))'")

        var files: [RemoteFile] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("total") else { continue }

            if let file = parseLsLine(trimmed, basePath: resolvedPath) {
                guard file.name != "." && file.name != ".." else { continue }
                files.append(file)
            }
        }

        return RemoteFile.sortedFiles(files, by: .name)
    }

    func getFileInfo(at path: String) async throws -> RemoteFile {
        let resolvedPath = resolvePath(path)
        let output = try await executeSSHCommand("ls -ld --time-style='+%Y-%m-%d %H:%M:%S' '\(escaped(resolvedPath))' 2>/dev/null || ls -ld '\(escaped(resolvedPath))'")

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let file = parseLsLine(trimmed, basePath: "") else {
            throw AppError.fileNotFound
        }
        return file
    }

    func createDirectory(at path: String) async throws {
        let resolvedPath = resolvePath(path)
        _ = try await executeSSHCommand("mkdir -p '\(escaped(resolvedPath))'")
    }

    func createFile(at path: String) async throws {
        let resolvedPath = resolvePath(path)
        _ = try await executeSSHCommand("touch '\(escaped(resolvedPath))'")
    }

    func deleteFile(at path: String) async throws {
        let resolvedPath = resolvePath(path)
        _ = try await executeSSHCommand("rm -f '\(escaped(resolvedPath))'")
    }

    func deleteDirectory(at path: String) async throws {
        let resolvedPath = resolvePath(path)
        _ = try await executeSSHCommand("rm -rf '\(escaped(resolvedPath))'")
    }

    func rename(from sourcePath: String, to destinationPath: String) async throws {
        let resolvedSource = resolvePath(sourcePath)
        let resolvedDest = resolvePath(destinationPath)
        _ = try await executeSSHCommand("mv '\(escaped(resolvedSource))' '\(escaped(resolvedDest))'")
    }

    func copyFile(from sourcePath: String, to destinationPath: String) async throws {
        let resolvedSource = resolvePath(sourcePath)
        let resolvedDest = resolvePath(destinationPath)
        _ = try await executeSSHCommand("cp '\(escaped(resolvedSource))' '\(escaped(resolvedDest))'")
    }

    func copyDirectory(from sourcePath: String, to destinationPath: String) async throws {
        let resolvedSource = resolvePath(sourcePath)
        let resolvedDest = resolvePath(destinationPath)
        _ = try await executeSSHCommand("cp -r '\(escaped(resolvedSource))' '\(escaped(resolvedDest))'")
    }

    func move(from sourcePath: String, to destinationPath: String) async throws {
        try await rename(from: sourcePath, to: destinationPath)
    }

    func downloadFile(from remotePath: String, to localURL: URL) async throws {
        try await downloadFile(from: remotePath, to: localURL, progress: nil)
    }

    func downloadFile(from remotePath: String, to localURL: URL, progress: TransferProgressHandler?) async throws {
        let resolvedPath = resolvePath(remotePath)
        _ = try await executeSSHCommand("cat '\(escaped(resolvedPath))'", outputFile: localURL)
        progress?(Int64(100))
    }

    func uploadFile(from localURL: URL, to remotePath: String) async throws {
        try await uploadFile(from: localURL, to: remotePath, progress: nil)
    }

    func uploadFile(from localURL: URL, to remotePath: String, progress: TransferProgressHandler?) async throws {
        let resolvedPath = resolvePath(remotePath)
        let localPath = localURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")

        var arguments = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=30",
            "-P", String(port)
        ]

        if let askpassPath = askpassScriptPath, let password = password {
            var environment = ProcessInfo.processInfo.environment
            environment["SSH_ASKPASS"] = askpassPath
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["DISPLAY"] = ":0"
            environment["MACSCP_ASKPASS_PASS"] = password
            process.environment = environment
        } else {
            arguments.append(contentsOf: ["-i", privateKeyPath])
        }

        arguments.append(contentsOf: [localPath, "\(username)@\(host):\(resolvedPath)"])
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AppError.uploadFailed("scp failed with exit code \(process.terminationStatus)")
        }
        progress?(Int64(100))
    }

    func readFileContent(at path: String) async throws -> String {
        let resolvedPath = resolvePath(path)
        return try await executeSSHCommand("cat '\(escaped(resolvedPath))'")
    }

    func writeFileContent(_ content: String, to path: String) async throws {
        let resolvedPath = resolvePath(path)
        _ = try await executeSSHCommand("cat > '\(escaped(resolvedPath))' << 'HEREDOC_EOF'\n\(content)\nHEREDOC_EOF")
    }

    func getRealPath(at path: String) async throws -> String {
        let resolvedPath = resolvePath(path)
        let realPath = try await executeSSHCommand("cd '\(escaped(resolvedPath))' 2>/dev/null && pwd || echo '\(escaped(resolvedPath))'")
        currentPath = realPath
        return realPath
    }

    func executeCommand(_ command: String) async throws -> String {
        return try await executeSSHCommand(command)
    }

    // MARK: - SSH Command Execution

    private func executeSSHCommand(_ command: String, outputFile: URL? = nil) async throws -> String {
        guard isConnected else { throw AppError.notConnected }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var arguments = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "BatchMode=no",
            "-p", String(port)
        ]

        if let askpassPath = askpassScriptPath, let password = password {
            var environment = ProcessInfo.processInfo.environment
            environment["SSH_ASKPASS"] = askpassPath
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["DISPLAY"] = ":0"
            environment["MACSCP_ASKPASS_PASS"] = password
            process.environment = environment
        } else {
            arguments.append(contentsOf: ["-i", privateKeyPath])
        }

        if let outputFile = outputFile {
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            arguments.append("\(username)@\(host)")
            arguments.append(command)
            process.arguments = arguments

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = (process.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                if errorMsg.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || errorMsg.contains("Host key verification failed") {
                    throw AppError.hostKeyMismatch(host: self.host, port: self.port)
                }
                throw AppError.sftpOperationFailed("ssh command failed with exit code \(process.terminationStatus)")
            }

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            try data.write(to: outputFile)
            return ""
        } else {
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()

            arguments.append("\(username)@\(host)")
            arguments.append(command)
            process.arguments = arguments

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = (process.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                if errorMsg.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || errorMsg.contains("Host key verification failed") {
                    throw AppError.hostKeyMismatch(host: self.host, port: self.port)
                }
                throw AppError.sftpOperationFailed("ssh command failed: \(errorMsg)")
            }

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    // MARK: - Helpers

    static var askpassScriptContent: String {
        "#!/bin/sh\nprintf '%s' \"$MACSCP_ASKPASS_PASS\"\n"
    }

    func writeAskpassScript(to path: String) throws {
        try Self.askpassScriptContent.write(toFile: path, atomically: true, encoding: .utf8)
        let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        try FileManager.default.setAttributes(attrs, ofItemAtPath: path)
    }

    func setAskpassScriptPath(_ path: String) throws {
        askpassScriptPath = path
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        if path == "." || path == "~" { return homePath }
        if path == ".." {
            let components = currentPath.split(separator: "/")
            if components.count > 1 {
                return "/" + components.dropLast().joined(separator: "/")
            }
            return "/"
        }
        return currentPath.hasSuffix("/") ? "\(currentPath)\(path)" : "\(currentPath)/\(path)"
    }

    private func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    // MARK: - ls Output Parsing

    /// Parses a single line of `ls -la` output.
    ///
    /// Supports two formats:
    /// 1. `--time-style='+%Y-%m-%d %H:%M:%S'`: `drwxr-xr-x 2 user group 4096 2024-01-15 14:30:45 filename`
    ///    → 8+ components (date at [5], time at [6], name at [7+])
    /// 2. Standard `ls -la`: `drwxr-xr-x 2 user group 4096 Jan 15 14:30 filename`
    ///    → 9+ components (month at [5], day at [6], time at [7], name at [8+])
    private func parseLsLine(_ line: String, basePath: String) -> RemoteFile? {
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count >= 8 else { return nil }

        let permissions = String(components[0])
        let size = Int64(components[4]) ?? 0

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        var modDate: Date?

        let comp5 = String(components[5])

        if comp5.contains("-") && comp5.count >= 10 {
            guard components.count >= 8 else { return nil }
            let dateStr = "\(comp5) \(components[6])"
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            modDate = dateFormatter.date(from: dateStr)
        } else {
            guard components.count >= 9 else { return nil }
            let dateStr = "\(components[5]) \(components[6]) \(components[7])"
            dateFormatter.dateFormat = "MMM dd HH:mm"
            modDate = dateFormatter.date(from: dateStr)
            if let date = modDate, Calendar.current.component(.year, from: date) == 2000 {
                var comps = Calendar.current.dateComponents([.month, .day, .hour, .minute, .second], from: date)
                comps.year = Calendar.current.component(.year, from: Date())
                modDate = Calendar.current.date(from: comps)
            }
        }

        let nameStartIndex = comp5.contains("-") && comp5.count >= 10 ? 7 : 8
        let name = components[nameStartIndex...]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        let isDirectory = permissions.first == "d"
        let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(name)" : "\(basePath)/\(name)"

        return RemoteFile(
            name: name,
            path: fullPath,
            isDirectory: isDirectory,
            size: size,
            permissions: permissions,
            modificationDate: modDate
        )
    }
}
