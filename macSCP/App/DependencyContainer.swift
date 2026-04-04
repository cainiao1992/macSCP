//
//  DependencyContainer.swift
//  macSCP
//
//  Dependency injection container for the application
//

import Foundation
import SwiftData
import Combine

@MainActor
final class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()

    // MARK: - Data Store
    lazy var dataStore: DataStore = {
        DataStore.shared
    }()

    var modelContainer: ModelContainer {
        dataStore.modelContainer
    }

    // MARK: - Keychain Service
    lazy var keychainService: KeychainServiceProtocol = {
        KeychainService.shared
    }()

    // MARK: - Repositories
    lazy var connectionRepository: ConnectionRepositoryProtocol = {
        ConnectionRepository(dataStore: dataStore)
    }()

    lazy var folderRepository: FolderRepositoryProtocol = {
        FolderRepository(dataStore: dataStore)
    }()

    // MARK: - Services
    lazy var appLockManager: AppLockManager = {
        AppLockManager.shared
    }()

    lazy var clipboardService: ClipboardService = {
        ClipboardService.shared
    }()

    lazy var windowManager: WindowManager = {
        WindowManager.shared
    }()

    // MARK: - SFTP Session Factory
    func makeSFTPSession(privateKeyPath: String? = nil) -> SFTPSessionProtocol {
        // For RSA keys, use the system ssh/sftp commands which properly
        // negotiate rsa-sha2-256/rsa-sha2-512 with modern OpenSSH 8.8+ servers.
        // Citadel's RSA implementation uses deprecated ssh-rsa (SHA1) signatures.
        if let keyPath = privateKeyPath,
           let keyContent = try? String(contentsOfFile: keyPath),
           isRSAKey(keyContent) {
            return SystemSFTPSession()
        }
        return SFTPSession()
    }

    private func isRSAKey(_ keyContent: String) -> Bool {
        // Traditional PEM RSA key
        if keyContent.contains("-----BEGIN RSA PRIVATE KEY-----") {
            return true
        }
        // OpenSSH format: try to detect by looking for ssh-rsa in the base64 payload
        if keyContent.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            // Extract base64 content between headers
            let lines = keyContent.components(separatedBy: .newlines)
            let base64Content = lines
                .filter { !$0.hasPrefix("-----") }
                .joined()
            // Decode and check for "ssh-rsa" marker in the OpenSSH binary format
            if let data = Data(base64Encoded: base64Content),
               let keyTypeStr = String(data: data, encoding: .ascii) {
                // OpenSSH format has "openssh-key-v1\0" magic followed by key type
                if keyTypeStr.contains("ssh-rsa") {
                    return true
                }
            }
            // Fallback: if we can't decode, assume it might be RSA for safety
            // The system ssh/sftp will handle it correctly either way
            return true
        }
        return false
    }

    // MARK: - S3 Session Factory
    func makeS3Session() -> S3SessionProtocol {
        S3Session()
    }

    // MARK: - Terminal Session Factory
    func makeTerminalSession(connectionData: TerminalWindowData) -> TerminalSessionProtocol {
        // For RSA keys, use the native system ssh command which properly
        // negotiates rsa-sha2-256/rsa-sha2-512 with modern OpenSSH 8.8+ servers.
        // Citadel's RSA implementation uses deprecated ssh-rsa (SHA1) signatures.
        if let keyPath = connectionData.privateKeyPath,
           let keyContent = try? String(contentsOfFile: keyPath),
           keyContent.contains("-----BEGIN OPENSSH PRIVATE KEY-----") || keyContent.contains("-----BEGIN RSA PRIVATE KEY-----") {
            return SystemTerminalSession()
        }
        return TerminalSession()
    }

    // MARK: - File Repository Factory
    func makeFileRepository(session: SFTPSessionProtocol) -> FileRepositoryProtocol {
        FileRepository(sftpSession: session)
    }

    func makeS3FileRepository(session: S3SessionProtocol) -> FileRepositoryProtocol {
        S3FileRepository(s3Session: session)
    }

    // MARK: - ViewModel Factories

    func makeConnectionListViewModel() -> ConnectionListViewModel {
        ConnectionListViewModel(
            connectionRepository: connectionRepository,
            folderRepository: folderRepository,
            keychainService: keychainService,
            windowManager: windowManager
        )
    }

    func makeFileBrowserViewModel(
        connection: Connection,
        sftpSession: SFTPSessionProtocol,
        password: String
    ) -> FileBrowserViewModel {
        let fileRepository = makeFileRepository(session: sftpSession)
        return FileBrowserViewModel(
            connection: connection,
            sftpSession: sftpSession,
            fileRepository: fileRepository,
            clipboardService: clipboardService,
            password: password
        )
    }

    func makeS3FileBrowserViewModel(
        connection: Connection,
        s3Session: S3SessionProtocol,
        secretAccessKey: String
    ) -> FileBrowserViewModel {
        let fileRepository = makeS3FileRepository(session: s3Session)
        return FileBrowserViewModel(
            connection: connection,
            s3Session: s3Session,
            fileRepository: fileRepository,
            clipboardService: clipboardService,
            secretAccessKey: secretAccessKey
        )
    }

    func makeFileEditorViewModel(
        filePath: String,
        fileName: String,
        content: String,
        sftpSession: SFTPSessionProtocol
    ) -> FileEditorViewModel {
        let fileRepository = makeFileRepository(session: sftpSession)
        return FileEditorViewModel(
            filePath: filePath,
            fileName: fileName,
            initialContent: content,
            fileRepository: fileRepository
        )
    }

    func makeFileInfoViewModel(file: RemoteFile, connectionName: String) -> FileInfoViewModel {
        FileInfoViewModel(file: file, connectionName: connectionName)
    }

    func makeTerminalViewModel(
        connectionName: String,
        session: TerminalSessionProtocol,
        connectionData: TerminalWindowData
    ) -> TerminalViewModel {
        TerminalViewModel(
            connectionName: connectionName,
            session: session,
            connectionData: connectionData
        )
    }

    private init() {
        logInfo("DependencyContainer initialized", category: .app)
    }
}

// MARK: - Preview Support
extension DependencyContainer {
    static var preview: DependencyContainer {
        let container = DependencyContainer.shared
        // Configure for preview if needed
        return container
    }
}
