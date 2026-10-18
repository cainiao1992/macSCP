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

    /// Transport used to run an ssh command. The default path spawns the system
    /// `ssh` binary; tests inject a stub so listing and parsing can be exercised
    /// without a live server.
    typealias SSHCommandTransport = @Sendable (String) async throws -> String

    private let commandTransport: SSHCommandTransport?

    init(commandTransport: SSHCommandTransport? = nil) {
        self.commandTransport = commandTransport
    }

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

        do {
            currentPath = try await executeSSHCommand("pwd")
        } catch {
            // Verify before arming isConnected: a failed probe must not leave a
            // session that later calls treat as connected.
            isConnected = false
            self.password = nil
            try? FileManager.default.removeItem(atPath: scriptPath)
            askpassScriptPath = nil
            throw error
        }
        homePath = currentPath
        isConnected = true
        logInfo("System SFTP connected to \(host) via password auth", category: .sftp)
    }

    func connect(host: String, port: Int, username: String, privateKeyPath: String, passphrase: String?) async throws {
        logInfo("System SFTP connecting to \(username)@\(host):\(port)", category: .sftp)

        self.host = host
        self.port = port
        self.username = username
        self.privateKeyPath = privateKeyPath
        do {
            currentPath = try await executeSSHCommand("pwd")
        } catch {
            isConnected = false
            throw error
        }
        homePath = currentPath
        isConnected = true
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

    /// Runs an `ls`-style command, surfacing the target path in the error so a
    /// failed listing is not mistaken for an empty directory or a missing entry.
    /// `2>/dev/null` is deliberately avoided: the exit code and stderr must
    /// reach this layer to be classified.
    private func listingOutput(_ command: String, path: String) async throws -> String {
        do {
            return try await executeSSHCommand(command)
        } catch let appError as AppError {
            logError("Failed to list \(path): \(appError)", category: .sftp)
            switch appError {
            case .notConnected, .hostKeyMismatch:
                throw appError
            default:
                throw AppError.sftpOperationFailed(
                    "Failed to list \(path): \(appError.localizedDescription)"
                )
            }
        } catch {
            logError("Failed to list \(path): \(error)", category: .sftp)
            throw AppError.sftpOperationFailed(
                "Failed to list \(path): \(error.localizedDescription)"
            )
        }
    }

    func listFiles(at path: String) async throws -> [RemoteFile] {
        let resolvedPath = resolvePath(path)
        currentPath = resolvedPath

        let output = try await listingOutput(
            "ls -la --time-style='+%Y-%m-%d %H:%M:%S' '\(escaped(resolvedPath))' || ls -la '\(escaped(resolvedPath))'",
            path: resolvedPath
        )

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
        let output = try await listingOutput(
            "ls -ld --time-style='+%Y-%m-%d %H:%M:%S' '\(escaped(resolvedPath))' || ls -ld '\(escaped(resolvedPath))'",
            path: resolvedPath
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // `ls -ld` echoes an absolute operand verbatim, so anchor the parsed
        // entry at its parent directory instead of the current path.
        let parentPath = (resolvedPath as NSString).deletingLastPathComponent
        guard let file = parseLsLine(trimmed, basePath: parentPath) else {
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
        _ = try await executeSSHCommand(
            "cat '\(escaped(resolvedPath))'",
            outputFile: localURL,
            progress: progress
        )
    }

    func uploadFile(from localURL: URL, to remotePath: String) async throws {
        try await uploadFile(from: localURL, to: remotePath, progress: nil)
    }

    func uploadFile(from localURL: URL, to remotePath: String, progress: TransferProgressHandler?) async throws {
        // Matches executeSSHCommand's guard: a disconnected session must fail
        // loudly instead of running scp with an empty key path.
        guard isConnected else { throw AppError.notConnected }
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

        // scp parses the remote spec with a shell on the far side: quote once
        // for the local argv, once for the remote shell.
        let remoteSpec = "\(username)@\(host):'\(escaped(resolvedPath))'"
        arguments.append(contentsOf: [localPath, remoteSpec])
        process.arguments = arguments

        try Task.checkCancellation()
        try process.run()

        // Await exit asynchronously so cancellation can terminate scp — a
        // plain waitUntilExit() is uninterruptible, so a cancelled upload
        // would run to completion anyway. stderr is drained after exit:
        // scp writes little there (progress goes to stdout), so the pipe
        // cannot fill during the transfer.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    let errorData = (proc.standardError as? Pipe)?
                        .fileHandleForReading.readDataToEndOfFile()
                    if proc.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let message = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                        continuation.resume(throwing: AppError.uploadFailed(
                            "scp failed with exit code \(proc.terminationStatus): \(message)"
                        ))
                    }
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }

        // TransferProgressHandler carries bytes, not percent — report the
        // file size so the finished transfer shows consistent numbers.
        let fileSize = (try? FileManager.default.attributesOfItem(
            atPath: localPath
        )[.size] as? Int64) ?? 0
        progress?(fileSize)
    }

    func readFileContent(at path: String) async throws -> String {
        let resolvedPath = resolvePath(path)
        return try await executeSSHCommand("cat '\(escaped(resolvedPath))'")
    }

    func writeFileContent(_ content: String, to path: String) async throws {
        let resolvedPath = resolvePath(path)
        // Content goes through stdin: embedding it in the command line (heredoc)
        // lets a lone "HEREDOC_EOF" line terminate the heredoc early and execute
        // the remaining lines as shell commands on the remote host.
        try await executeSSHCommand(
            "cat > '\(escaped(resolvedPath))'",
            standardInput: Data(content.utf8)
        )
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

    /// Chunk size for streaming stdout to disk (reads must happen while the
    /// child runs; the OS pipe buffer is far smaller than typical transfers).
    private static let streamChunkSize = 1 << 16

    private func executeSSHCommand(
        _ command: String,
        outputFile: URL? = nil,
        standardInput: Data? = nil,
        progress: TransferProgressHandler? = nil
    ) async throws -> String {
        if let commandTransport, outputFile == nil, standardInput == nil {
            return try await commandTransport(command)
        }

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

        if standardInput != nil {
            process.standardInput = Pipe()
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        arguments.append("\(username)@\(host)")
        arguments.append(command)
        process.arguments = arguments

        try process.run()

        // Feed stdin from a side thread, concurrently with draining stdout:
        // writing on the actor would block the whole session when the remote
        // consumes slowly (e.g. `cat > file` stalled on a full disk) — even
        // disconnect() queues behind it and can never run. Depends on
        // signal(SIGPIPE, SIG_IGN) installed at app startup, so a mid-transfer
        // ssh death surfaces as a write error instead of killing the process.
        if let standardInput, let inputPipe = process.standardInput as? Pipe {
            let handle = inputPipe.fileHandleForWriting
            let payload = standardInput
            Thread.detachNewThread {
                try? handle.write(contentsOf: payload)
                try? handle.close()
            }
        }

        // Drain pipes BEFORE waiting for exit: a full pipe buffer blocks the
        // child forever, which would deadlock waitUntilExit.
        if let outputFile {
            do {
                if !FileManager.default.createFile(atPath: outputFile.path, contents: nil) {
                    throw AppError.downloadFailed("Cannot create \(outputFile.path)")
                }
                let destination = try FileHandle(forWritingTo: outputFile)
                defer { try? destination.close() }
                let source = stdoutPipe.fileHandleForReading
                var transferred: Int64 = 0
                while let chunk = try source.read(upToCount: Self.streamChunkSize), !chunk.isEmpty {
                    // Terminate the child on cancel: otherwise the transfer runs
                    // to completion while the UI already shows "cancelled".
                    try Task.checkCancellation()
                    try destination.write(contentsOf: chunk)
                    transferred += Int64(chunk.count)
                    progress?(transferred)
                }
            } catch {
                process.terminate()
                process.waitUntilExit()
                // Never leave a truncated/partial file behind.
                try? FileManager.default.removeItem(atPath: outputFile.path)
                throw error
            }
        }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            if let outputFile {
                try? FileManager.default.removeItem(atPath: outputFile.path)
            }
            if errorMsg.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") || errorMsg.contains("Host key verification failed") {
                throw AppError.hostKeyMismatch(host: self.host, port: self.port)
            }
            throw AppError.sftpOperationFailed("ssh command failed with exit code \(process.terminationStatus): \(errorMsg)")
        }

        if outputFile != nil {
            return ""
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        var name = lineAfterFields(line, count: nameStartIndex)
            .trimmingCharacters(in: .whitespaces)
        // `ls -la` renders symlinks as "name -> target"; keep the link name only.
        if permissions.first == "l" {
            name = name.components(separatedBy: " -> ").first ?? name
        }
        guard !name.isEmpty else { return nil }

        let isDirectory = permissions.first == "d"
        // `ls -ld` echoes an absolute operand as-is; re-prefixing it with the
        // base directory would corrupt the path.
        let fullPath: String
        if name.hasPrefix("/") {
            fullPath = name
        } else if basePath.hasSuffix("/") {
            fullPath = "\(basePath)\(name)"
        } else {
            fullPath = "\(basePath)/\(name)"
        }

        return RemoteFile(
            name: name,
            path: fullPath,
            isDirectory: isDirectory,
            size: size,
            permissions: permissions,
            modificationDate: modDate
        )
    }

    /// Returns everything after the first `count` whitespace-separated fields
    /// of `line`, preserving original spacing (names may contain runs of
    /// spaces that `split` + `join` would collapse).
    private func lineAfterFields(_ line: String, count: Int) -> Substring {
        var index = line.startIndex
        var fieldsSeen = 0
        var inField = false
        while index < line.endIndex && fieldsSeen < count {
            if line[index].isWhitespace {
                if inField {
                    fieldsSeen += 1
                    inField = false
                }
            } else {
                inField = true
            }
            index = line.index(after: index)
        }
        return line[index...]
    }
}
