//
//  ConnectionLifecycleCoordinator.swift
//  macSCP
//
//  Owns the SFTP/S3 connect/host-key lifecycle. Performs no VM state mutation —
//  returns a ConnectionOutcome the FileBrowserViewModel applies to its
//  @Observable state. Extracted from FileBrowserViewModel for independent
//  testability (VM-SPLIT-01).
//

import Foundation

/// Outcome of a connection attempt. The coordinator never touches VM state;
/// the VM switches on this enum to update its @Observable properties.
enum ConnectionOutcome: Sendable {
    /// Session connected; `currentPath` is the authoritative path reported by the session.
    case connected(currentPath: String)
    /// The server's host key changed — VM must surface the host-key alert.
    case hostKeyMismatch(host: String, port: Int)
    /// Any other failure, already wrapped via `AppError.from`.
    case error(AppError)
}

@MainActor
final class ConnectionLifecycleCoordinator {
    // MARK: - Dependencies
    private let connection: Connection
    private let sftpSession: SFTPSessionProtocol?
    private let s3Session: S3SessionProtocol?
    private let password: String

    // MARK: - Host Key Mismatch State
    // Remembered between connect() surfacing a mismatch and a later
    // replaceHostKeyAndConnect() removing the offending key.
    private var hostKeyMismatchHost = ""
    private var hostKeyMismatchPort = 22

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        connection: Connection,
        sftpSession: SFTPSessionProtocol?,
        s3Session: S3SessionProtocol?,
        password: String
    ) {
        self.connection = connection
        self.sftpSession = sftpSession
        self.s3Session = s3Session
        self.password = password
    }

    // MARK: - Connect

    /// Attempts a connection and returns the outcome. Mutates no VM state.
    func connect() async -> ConnectionOutcome {
        do {
            if connection.connectionType == .s3 {
                return try await connectS3()
            } else {
                return try await connectSFTP()
            }
        } catch {
            logError("Connection failed: \(error)", category: connection.connectionType == .s3 ? .s3 : .sftp)
            let appError = AppError.from(error)
            if case .hostKeyMismatch(let host, let port) = appError {
                hostKeyMismatchHost = host
                hostKeyMismatchPort = port
                return .hostKeyMismatch(host: host, port: port)
            }
            return .error(appError)
        }
    }

    /// Disconnects the active session. The VM applies the post-disconnect
    /// state reset (isConnected/files/currentPath/navigation history).
    func disconnect() async {
        if connection.connectionType == .s3 {
            await s3Session?.disconnect()
        } else {
            await sftpSession?.disconnect()
        }
    }

    /// Removes the stored offending host key, clears the remembered mismatch
    /// state, then retries the connection and returns its outcome.
    func replaceHostKeyAndConnect() async -> ConnectionOutcome {
        do {
            try HostKeyService.removeHostKey(host: hostKeyMismatchHost, port: hostKeyMismatchPort)
            logInfo("Host key replaced, retrying connection", category: .sftp)
        } catch {
            logError("Failed to remove host key: \(error)", category: .sftp)
        }
        // Clear mismatch state regardless of the removeHostKey outcome, then retry.
        hostKeyMismatchHost = ""
        hostKeyMismatchPort = 22
        return await connect()
    }

    // MARK: - Private Connect Paths

    private func connectS3() async throws -> ConnectionOutcome {
        guard let s3Session = s3Session else {
            throw AppError.notConnected
        }
        try await s3Session.connect(
            accessKeyId: connection.username,
            secretAccessKey: password,
            region: connection.s3Region ?? "us-east-1",
            bucket: connection.s3Bucket ?? "",
            endpoint: connection.s3Endpoint
        )
        let path = await s3Session.currentPath
        AnalyticsService.trackFileBrowserOpened(protocol: .init(from: connection.connectionType))
        return .connected(currentPath: path)
    }

    private func connectSFTP() async throws -> ConnectionOutcome {
        guard let sftpSession = sftpSession else {
            throw AppError.notConnected
        }
        if connection.authMethod == .password {
            try await sftpSession.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password
            )
        } else if let keyPath = connection.privateKeyPath {
            try await sftpSession.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                privateKeyPath: keyPath,
                passphrase: password.isEmpty ? nil : password
            )
        }
        let path = await sftpSession.currentPath
        AnalyticsService.trackFileBrowserOpened(protocol: .init(from: connection.connectionType))
        return .connected(currentPath: path)
    }
}
