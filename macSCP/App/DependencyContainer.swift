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

    // MARK: - Tab Manager

    lazy var tabManager: TabManager = {
        TabManager(dependencyContainer: self)
    }()

    // MARK: - SFTP Session Factory
    func makeSFTPSession(privateKeyPath: String? = nil) -> SFTPSessionProtocol {
        SystemSFTPSession()
    }

    // MARK: - S3 Session Factory
    func makeS3Session() -> S3SessionProtocol {
        S3Session()
    }

    // MARK: - Terminal Session Factory
    func makeTerminalSession(connectionData: TerminalWindowData) -> TerminalSessionProtocol {
        SystemTerminalSession()
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
            windowManager: windowManager,
            tabManager: tabManager,
            appLockManager: appLockManager
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
            windowManager: windowManager,
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
            windowManager: windowManager,
            secretAccessKey: secretAccessKey
        )
    }

    /// Unified factory: creates the right FileBrowserViewModel from connection data + password/secret.
    /// Handles both SFTP and S3 branching internally.
    func makeFileBrowserViewModel(connection: Connection, password: String) -> FileBrowserViewModel {
        if connection.connectionType == .s3 {
            let session = makeS3Session()
            return makeS3FileBrowserViewModel(
                connection: connection,
                s3Session: session,
                secretAccessKey: password
            )
        } else {
            let session = makeSFTPSession(privateKeyPath: connection.privateKeyPath)
            return makeFileBrowserViewModel(
                connection: connection,
                sftpSession: session,
                password: password
            )
        }
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

    /// Encapsulates the session-creation + connect logic needed by
    /// FileEditorWindow, so the Window itself never reaches into the container.
    /// Returns the file repository plus the live S3/SFTP session (whichever
    /// branch was taken) so the editor can clean it up on close.
    func makeFileEditorDependencies(
        for data: FileEditorWindowData
    ) async throws -> (FileRepositoryProtocol, S3SessionProtocol?, SFTPSessionProtocol?) {
        let fileRepository: FileRepositoryProtocol
        var s3Session: S3SessionProtocol?
        var sftpSession: SFTPSessionProtocol?

        if data.connectionType == .s3 {
            // S3 connection
            let session = makeS3Session()
            try await session.connect(
                accessKeyId: data.username,
                secretAccessKey: data.password,
                region: data.s3Region ?? "us-east-1",
                bucket: data.s3Bucket ?? "",
                endpoint: data.s3Endpoint
            )
            fileRepository = makeS3FileRepository(session: session)
            s3Session = session
        } else {
            // SFTP connection
            let session = makeSFTPSession(privateKeyPath: data.privateKeyPath)
            switch data.authMethod {
            case .password:
                try await session.connect(
                    host: data.host,
                    port: data.port,
                    username: data.username,
                    password: data.password
                )
            case .privateKey:
                try await session.connect(
                    host: data.host,
                    port: data.port,
                    username: data.username,
                    privateKeyPath: data.privateKeyPath ?? "",
                    passphrase: data.password.isEmpty ? nil : data.password
                )
            }
            fileRepository = makeFileRepository(session: session)
            sftpSession = session
        }

        return (fileRepository, s3Session, sftpSession)
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

    /// Convenience factory for terminal tabs: builds TerminalWindowData + session from a connection.
    func makeTerminalViewModel(connection: Connection, password: String) -> TerminalViewModel {
        let data = TerminalWindowData(
            connectionId: connection.id,
            connectionName: connection.name,
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: password,
            authMethod: connection.authMethod,
            privateKeyPath: connection.privateKeyPath
        )
        let session = makeTerminalSession(connectionData: data)
        return makeTerminalViewModel(
            connectionName: connection.name,
            session: session,
            connectionData: data
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
