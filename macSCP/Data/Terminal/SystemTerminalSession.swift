//
//  SystemTerminalSession.swift
//  macSCP
//
//  Terminal session using the system `ssh` command via PTY.
//  This allows RSA keys to work with modern OpenSSH 8.8+ servers
//  because the system ssh client automatically negotiates
//  rsa-sha2-256/rsa-sha2-512 instead of deprecated ssh-rsa (SHA1).
//

import Foundation

actor SystemTerminalSession: TerminalSessionProtocol {
    private var masterFD: Int32 = -1
    private var childPID: pid_t = 0
    private var outputContinuation: AsyncStream<Data>.Continuation?
    private var _outputStream: AsyncStream<Data>?
    private var currentSize: TerminalSize = .default
    private var readTask: Task<Void, Never>?
    private(set) var isConnected = false
    private(set) var sessionEndedGracefully = false

    var outputStream: AsyncStream<Data> {
        get async {
            if let stream = _outputStream { return stream }
            let (stream, continuation) = AsyncStream<Data>.makeStream()
            outputContinuation = continuation
            _outputStream = stream
            return stream
        }
    }

    init() {}

    // MARK: - Connection

    func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        terminalSize: TerminalSize
    ) async throws {
        throw AppError.connectionFailed("System session requires private key authentication")
    }

    func connect(
        host: String,
        port: Int,
        username: String,
        privateKeyPath: String,
        passphrase: String?,
        terminalSize: TerminalSize
    ) async throws {
        logInfo("System terminal connecting to \(username)@\(host):\(port)", category: .network)

        currentSize = terminalSize
        sessionEndedGracefully = false
        _ = await outputStream

        // Open PTY master
        let fd = posix_openpt(O_RDWR)
        guard fd >= 0 else {
            throw AppError.terminalConnectionFailed("Failed to open PTY")
        }
        guard grantpt(fd) == 0, unlockpt(fd) == 0 else {
            close(fd)
            throw AppError.terminalConnectionFailed("Failed to configure PTY")
        }

        let slaveName = ptsname(fd)
        guard let slaveName = slaveName else {
            close(fd)
            throw AppError.terminalConnectionFailed("Failed to get PTY name")
        }

        // Set initial size
        var winsize = winsize(
            ws_row: UInt16(currentSize.rows),
            ws_col: UInt16(currentSize.columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        ioctl(fd, TIOCSWINSZ, &winsize)

        // Build ssh command
        let sshArgs: [String] = [
            "/usr/bin/ssh",
            "-t",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "BatchMode=no",
            "-i", privateKeyPath,
            "-p", String(port),
            "\(username)@\(host)"
        ]

        // Convert to C arrays for posix_spawn
        let argv: [UnsafeMutablePointer<CChar>?] = sshArgs.map { strdup($0) } + [nil]
        let envp = environ

        // Set up file actions to use the PTY slave for stdio
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)

        // Open the slave PTY and dup to stdin/stdout/stderr
        posix_spawn_file_actions_addopen(&fileActions, STDIN_FILENO, slaveName, O_RDWR, 0)
        posix_spawn_file_actions_addopen(&fileActions, STDOUT_FILENO, slaveName, O_RDWR, 0)
        posix_spawn_file_actions_addopen(&fileActions, STDERR_FILENO, slaveName, O_RDWR, 0)

        // Set up attributes for session leader
        var attrs: posix_spawnattr_t?
        posix_spawnattr_init(&attrs)
        posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETPGROUP))

        var pid: pid_t = 0
        let spawnResult = argv.withUnsafeBufferPointer { argvPtr in
            posix_spawn(&pid, "/usr/bin/ssh", &fileActions, &attrs,
                       UnsafeMutablePointer(mutating: argvPtr.baseAddress), envp)
        }

        // Clean up C strings
        for arg in argv where arg != nil {
            free(arg)
        }
        posix_spawnattr_destroy(&attrs)
        posix_spawn_file_actions_destroy(&fileActions)

        guard spawnResult == 0 else {
            close(fd)
            throw AppError.terminalConnectionFailed("posix_spawn failed with error code \(spawnResult)")
        }

        masterFD = fd
        childPID = pid
        isConnected = true

        // Set non-blocking on master
        fcntl(masterFD, F_SETFL, fcntl(masterFD, F_GETFL) | O_NONBLOCK)

        // Start reading from PTY
        startReading()

        logInfo("System terminal connected to \(host)", category: .network)
    }

    // MARK: - Read Loop

    private func startReading() {
        readTask = Task {
            let fd = masterFD
            guard fd >= 0 else { return }

            let bufferSize = 4096
            while !Task.isCancelled {
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                let bytesRead = read(fd, &buffer, bufferSize)

                if bytesRead > 0 {
                    let data = Data(buffer[..<Int(bytesRead)])
                    outputContinuation?.yield(data)
                } else if bytesRead == 0 {
                    break
                } else {
                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        try? await Task.sleep(for: .milliseconds(10))
                        continue
                    }
                    break
                }
            }

            isConnected = false
            sessionEndedGracefully = true
            outputContinuation?.finish()
        }
    }

    // MARK: - Send Data

    func send(_ data: Data) async throws {
        guard isConnected, masterFD >= 0 else {
            throw AppError.notConnected
        }

        _ = data.withUnsafeBytes { ptr in
            write(masterFD, ptr.baseAddress, data.count)
        }
    }

    // MARK: - Resize

    func resize(columns: Int, rows: Int) async throws {
        guard isConnected, masterFD >= 0 else { return }

        currentSize = TerminalSize(columns: columns, rows: rows)

        var winsize = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        ioctl(masterFD, TIOCSWINSZ, &winsize)
    }

    // MARK: - Disconnect

    func disconnect() async {
        logInfo("Disconnecting native terminal", category: .network)

        readTask?.cancel()
        readTask = nil

        if childPID > 0 {
            kill(childPID, SIGHUP)
        }

        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }

        outputContinuation?.finish()
        outputContinuation = nil
        _outputStream = nil

        isConnected = false
    }
}
