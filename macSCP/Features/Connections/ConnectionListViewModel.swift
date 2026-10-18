//
//  ConnectionListViewModel.swift
//  macSCP
//
//  ViewModel for the connection list feature
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum SidebarSelection: Hashable, Sendable {
    case allConnections
    case folder(UUID)
}

/// Export scope for JSON connection export (EXP-02).
enum ExportScope {
    case all
    case selected
}

enum TestConnectionState: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

@MainActor
@Observable
final class ConnectionListViewModel {
    // MARK: - Published State
    private(set) var connections: [Connection] = []
    private(set) var folders: [Folder] = []
    private(set) var state: ViewState<Void> = .idle
    var error: AppError?
    private(set) var testConnectionState: TestConnectionState = .idle
    private(set) var connectionStatuses: [UUID: ConnectionStatus] = [:]

    var selectedSidebarItem: SidebarSelection = .allConnections
    var searchText: String = ""
    var selectedConnectionId: UUID?

    // Sheet states
    var isShowingNewConnectionSheet = false
    var isShowingEditConnectionSheet = false
    var isShowingNewFolderSheet = false
    var isShowingPasswordPrompt = false
    var isShowingDeleteFolderAlert = false
    var isShowingImportSheet = false
    var isShowingExportChoice = false
    var isShowingJSONImportSheet = false

    // Editing state
    var connectionToEdit: Connection?
    var connectionToConnect: Connection?
    var folderToDelete: Folder?

    // MARK: - Dependencies
    private let connectionRepository: ConnectionRepositoryProtocol
    private let folderRepository: FolderRepositoryProtocol
    private let keychainService: KeychainServiceProtocol
    private let windowManager: any WindowManagerProtocol
    private let tabManager: TabManager
    private let appLockManager: any AppLockManagerProtocol
    private let makeSFTPSession: () -> any SFTPSessionProtocol
    private let makeS3Session: () -> any S3SessionProtocol
    static let testConnectionTimeout: Duration = .seconds(15)
    private let connectivityService: ConnectivityService

    // MARK: - Sub-components (coordinators)
    @ObservationIgnored
    private lazy var connectionInitiator: ConnectionInitiator = {
        ConnectionInitiator(
            keychainService: keychainService,
            tabManager: tabManager,
            appLockManager: appLockManager,
            getConnectionToConnect: { [weak self] in self?.connectionToConnect },
            onSetConnectionToConnect: { [weak self] conn in self?.connectionToConnect = conn },
            onShowPasswordPrompt: { [weak self] show in self?.isShowingPasswordPrompt = show }
        )
    }()

    @ObservationIgnored
    private lazy var crudCoordinator: ConnectionCRUDCoordinator = {
        ConnectionCRUDCoordinator(
            connectionRepository: connectionRepository,
            keychainService: keychainService,
            onReloadData: { [weak self] in await self?.loadData() },
            onError: { [weak self] error in self?.error = error },
            onConnectionMoved: { _, _ in }
        )
    }()

    // MARK: - Initialization
    init(
        connectionRepository: ConnectionRepositoryProtocol,
        folderRepository: FolderRepositoryProtocol,
        keychainService: KeychainServiceProtocol,
        windowManager: any WindowManagerProtocol,
        tabManager: TabManager,
        appLockManager: any AppLockManagerProtocol,
        makeSFTPSession: (() -> any SFTPSessionProtocol)? = nil,
        makeS3Session: (() -> any S3SessionProtocol)? = nil,
        connectivityService: ConnectivityService? = nil
    ) {
        self.connectionRepository = connectionRepository
        self.folderRepository = folderRepository
        self.keychainService = keychainService
        self.windowManager = windowManager
        self.tabManager = tabManager
        self.appLockManager = appLockManager
        self.makeSFTPSession = makeSFTPSession ?? { DependencyContainer.shared.makeSFTPSession() }
        self.makeS3Session = makeS3Session ?? { DependencyContainer.shared.makeS3Session() }
        self.connectivityService = connectivityService ?? ConnectivityService.shared
    }

    // MARK: - Computed Properties

    var filteredConnections: [Connection] {
        var result: [Connection]

        switch selectedSidebarItem {
        case .allConnections:
            result = connections
        case .folder(let folderId):
            result = connections.filter { $0.folderId == folderId }
        }

        if !searchText.isEmpty {
            result = result.filter { connection in
                connection.name.localizedCaseInsensitiveContains(searchText) ||
                connection.host.localizedCaseInsensitiveContains(searchText) ||
                connection.username.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var unfolderedConnections: [Connection] {
        connections.filter { $0.folderId == nil }
    }

    var favoriteConnections: [Connection] {
        connections.filter(\.isFavorite)
    }

    var recentConnections: [Connection] {
        let base = searchText.isEmpty ? connections : connections.filter { conn in
            conn.name.localizedCaseInsensitiveContains(searchText) ||
            conn.host.localizedCaseInsensitiveContains(searchText) ||
            conn.username.localizedCaseInsensitiveContains(searchText)
        }
        return base
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var totalConnectionCount: Int {
        connections.count
    }

    func connectionCount(for folderId: UUID) -> Int {
        connections.filter { $0.folderId == folderId }.count
    }

    var selectedConnection: Connection? {
        guard let id = selectedConnectionId else { return nil }
        return connections.first { $0.id == id }
    }

    // MARK: - Keyboard Navigation

    /// Flat list of all visible connections in display order (recent, favorites, unfoldered, folders).
    var navigableConnections: [Connection] {
        var result: [Connection] = []
        var seen = Set<UUID>()

        for conn in recentConnections {
            if seen.insert(conn.id).inserted { result.append(conn) }
        }
        for conn in filteredConnections where conn.isFavorite {
            if seen.insert(conn.id).inserted { result.append(conn) }
        }
        for conn in filteredConnections where conn.folderId == nil {
            if seen.insert(conn.id).inserted { result.append(conn) }
        }
        for folder in folders {
            for conn in filteredConnections where conn.folderId == folder.id {
                if seen.insert(conn.id).inserted { result.append(conn) }
            }
        }
        return result
    }

    func selectAdjacentConnection(direction: Int) {
        let list = navigableConnections
        guard !list.isEmpty else { return }

        if let currentId = selectedConnectionId,
           let idx = list.firstIndex(where: { $0.id == currentId }) {
            let newIndex = min(max(idx + direction, 0), list.count - 1)
            selectedConnectionId = list[newIndex].id
        } else {
            selectedConnectionId = direction > 0 ? list.first?.id : list.last?.id
        }
    }

    var selectedFolder: Folder? {
        guard case .folder(let id) = selectedSidebarItem else { return nil }
        return folders.first { $0.id == id }
    }

    // MARK: - Export (EXP-01, EXP-02)

    /// Exports connections to a JSON file via NSSavePanel.
    ///
    /// Security (T-6-01): the export path NEVER reads Keychain — it only reads
    /// the already-loaded `connections` / `folders` models and encodes them via
    /// `ConnectionExportCodec`. `Connection` has no password/s3Secret field, so
    /// the resulting JSON is secret-free by construction (proven by
    /// `testExport_containsNoSecretFields`).
    func exportConnections(_ scope: ExportScope) {
        let scoped: [Connection]
        switch scope {
        case .all:
            scoped = connections
        case .selected:
            guard let selected = connections.first(where: { $0.id == selectedConnectionId }) else {
                return
            }
            scoped = [selected]
        }

        guard !scoped.isEmpty else {
            error = AppError.unknown("No connections to export")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Connections"
        panel.nameFieldStringValue = "macscp-connections.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let file = ConnectionExportFile(
                version: ConnectionExportFile.currentVersion,
                exportedAt: Date(),
                appVersion: appVersionString(),
                connections: scoped,
                folders: folders
            )
            let data = try ConnectionExportCodec.encoder().encode(file)
            try data.write(to: url, options: .atomic)
            logInfo("Exported \(scoped.count) connections to \(url.path)", category: .database)
        } catch {
            logError("Failed to export connections: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    /// Reads the app's marketing version from the bundle for the export envelope.
    private func appVersionString() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Data Loading

    func loadData() async {
        state = .loading

        do {
            async let connectionsTask = connectionRepository.fetchAll()
            async let foldersTask = folderRepository.fetchAll()

            connections = try await connectionsTask
            folders = try await foldersTask
            state = .success(())

            // Trigger on-demand connectivity check (LIST-03)
            Task { await checkAllConnectionStatuses() }
        } catch {
            logError("Failed to load data: \(error)", category: .database)
            state = .error(AppError.from(error))
        }
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Connectivity Status

    func checkConnectionStatus(_ connection: Connection) async {
        guard connection.connectionType == .sftp else { return }
        connectionStatuses[connection.id] = .checking
        let status = await connectivityService.checkConnectivity(
            host: connection.host,
            port: connection.port
        )
        connectionStatuses[connection.id] = status
    }

    func checkAllConnectionStatuses() async {
        await withTaskGroup(of: Void.self) { group in
            for connection in connections where connection.connectionType == .sftp {
                group.addTask { @MainActor [weak self] in
                    await self?.checkConnectionStatus(connection)
                }
            }
        }
    }

    // MARK: - Connection Actions

    func saveConnection(_ connection: Connection, password: String?) async {
        do {
            try await connectionRepository.save(connection)

            if connection.savePassword, let password = password, !password.isEmpty {
                if connection.connectionType == .s3 {
                    // For S3, store credentials (username is access key, password is secret)
                    let credentials = S3Credentials(
                        accessKeyId: connection.username,
                        secretAccessKey: password
                    )
                    try keychainService.saveS3Credentials(credentials, for: connection.id)
                } else {
                    try keychainService.savePassword(password, for: connection.id)
                }
            }

            await loadData()
            isShowingNewConnectionSheet = false
            AnalyticsService.trackConnectionCreated(protocol: .init(from: connection.connectionType))
            logInfo("Connection saved: \(connection.name)", category: .database)
        } catch {
            logError("Failed to save connection: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func updateConnection(_ connection: Connection, password: String?) async {
        do {
            try await connectionRepository.update(connection)

            if connection.savePassword, let password = password, !password.isEmpty {
                if connection.connectionType == .s3 {
                    let credentials = S3Credentials(
                        accessKeyId: connection.username,
                        secretAccessKey: password
                    )
                    try keychainService.updateS3Credentials(credentials, for: connection.id)
                } else {
                    try keychainService.updatePassword(password, for: connection.id)
                }
            } else if !connection.savePassword {
                if connection.connectionType == .s3 {
                    try? keychainService.deleteS3Credentials(for: connection.id)
                } else {
                    try? keychainService.deletePassword(for: connection.id)
                }
            }

            await loadData()
            isShowingEditConnectionSheet = false
            connectionToEdit = nil
            AnalyticsService.track(.connectionEdited, with: [
                "protocol": AnalyticsService.ConnectionProtocol(from: connection.connectionType).rawValue
            ])
            logInfo("Connection updated: \(connection.name)", category: .database)
        } catch {
            logError("Failed to update connection: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func deleteConnection(_ connection: Connection) async {
        do {
            try await connectionRepository.delete(id: connection.id)
            // Delete credentials based on connection type
            if connection.connectionType == .s3 {
                try? keychainService.deleteS3Credentials(for: connection.id)
            } else {
                try? keychainService.deletePassword(for: connection.id)
            }
            if selectedConnectionId == connection.id {
                selectedConnectionId = nil
            }
            await loadData()
            AnalyticsService.track(.connectionDeleted, with: [
                "protocol": AnalyticsService.ConnectionProtocol(from: connection.connectionType).rawValue
            ])
            logInfo("Connection deleted: \(connection.name)", category: .database)
        } catch {
            logError("Failed to delete connection: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func moveConnection(_ connection: Connection, to folder: Folder?) async {
        do {
            try await connectionRepository.move(connectionId: connection.id, toFolderId: folder?.id)
            // Update local state directly to avoid .loading flash
            if let index = connections.firstIndex(where: { $0.id == connection.id }) {
                connections[index].folderId = folder?.id
            }
            logInfo("Connection moved: \(connection.name)", category: .database)
        } catch {
            logError("Failed to move connection: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func toggleFavorite(_ connection: Connection) async {
        do {
            try await connectionRepository.toggleFavorite(id: connection.id)
            // Update local state directly to avoid .loading flash
            if let index = connections.firstIndex(where: { $0.id == connection.id }) {
                connections[index].isFavorite.toggle()
            }
            logInfo("Connection favorite toggled: \(connection.name)", category: .database)
        } catch {
            logError("Failed to toggle favorite: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    // MARK: - Folder Actions

    func createFolder(name: String) async {
        let nextOrder = (folders.map(\.displayOrder).max() ?? -1) + 1
        let folder = Folder(name: name, displayOrder: nextOrder)

        do {
            try await folderRepository.save(folder)
            await loadData()
            isShowingNewFolderSheet = false
            AnalyticsService.track(.folderCreated)
            logInfo("Folder created: \(name)", category: .database)
        } catch {
            logError("Failed to create folder: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func reorderFolders(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        for (index, _) in folders.enumerated() {
            folders[index].displayOrder = index
        }
        Task {
            do {
                try await folderRepository.updateOrder(folders)
            } catch {
                logError("Failed to reorder folders: \(error)", category: .database)
                self.error = AppError.from(error)
            }
        }
    }

    func renameFolder(_ folder: Folder, to newName: String) async {
        var updatedFolder = folder
        updatedFolder.name = newName

        do {
            try await folderRepository.update(updatedFolder)
            await loadData()
            logInfo("Folder renamed: \(newName)", category: .database)
        } catch {
            logError("Failed to rename folder: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    func deleteFolder(_ folder: Folder) async {
        do {
            try await folderRepository.delete(id: folder.id)
            if case .folder(let id) = selectedSidebarItem, id == folder.id {
                selectedSidebarItem = .allConnections
            }
            await loadData()
            isShowingDeleteFolderAlert = false
            folderToDelete = nil
            AnalyticsService.track(.folderDeleted)
            logInfo("Folder deleted: \(folder.name)", category: .database)
        } catch {
            logError("Failed to delete folder: \(error)", category: .database)
            self.error = AppError.from(error)
        }
    }

    // MARK: - Connection Operations

    func connectToServer(_ connection: Connection) {
        connectionInitiator.connectToServer(connection)
    }

    func connectWithPassword(_ password: String) {
        connectionInitiator.connectWithPassword(password)
    }

    func cancelConnect() {
        isShowingPasswordPrompt = false
        connectionToConnect = nil
    }

    // MARK: - Test Connection

    func testConnection(_ connection: Connection, password: String?) async {
        // Guard against missing/empty credentials before attempting the test
        let effectivePassword: String
        if let pw = password, !pw.isEmpty {
            effectivePassword = pw
        } else if connection.authMethod == .privateKey {
            effectivePassword = ""  // passphrase is optional for key auth
        } else {
            testConnectionState = .failure("Password is required for testing")
            return
        }

        testConnectionState = .testing

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Task 1: Attempt connection
                group.addTask { @MainActor [weak self] in
                    guard let self else { return }
                    if connection.connectionType == .s3 {
                        let session = self.makeS3Session()
                        defer { Task { await session.disconnect() } }
                        try await session.connect(
                            accessKeyId: connection.username,
                            secretAccessKey: effectivePassword,
                            region: connection.s3Region ?? "us-east-1",
                            bucket: connection.s3Bucket ?? "",
                            endpoint: connection.s3Endpoint
                        )
                    } else {
                        let session = self.makeSFTPSession()
                        defer { Task { await session.disconnect() } }
                        if connection.authMethod == .privateKey {
                            try await session.connect(
                                host: connection.host,
                                port: connection.port,
                                username: connection.username,
                                privateKeyPath: connection.privateKeyPath ?? "",
                                passphrase: effectivePassword.isEmpty ? nil : effectivePassword
                            )
                        } else {
                            try await session.connect(
                                host: connection.host,
                                port: connection.port,
                                username: connection.username,
                                password: effectivePassword
                            )
                        }
                    }
                }

                // Task 2: Timeout deadline
                group.addTask {
                    try await Task.sleep(for: Self.testConnectionTimeout)
                    throw AppError.connectionTimeout
                }

                // First task to finish wins; cancel the other
                try await group.next()
                group.cancelAll()
            }
            testConnectionState = .success
        } catch is CancellationError {
            testConnectionState = .failure(AppError.connectionTimeout.errorDescription ?? "Connection timed out")
        } catch {
            testConnectionState = .failure(error.localizedDescription)
        }
    }

    func resetTestConnectionState() {
        testConnectionState = .idle
    }

    // MARK: - Terminal Operations

    func requestTerminal(for connection: Connection) {
        connectionInitiator.requestTerminal(for: connection)
    }

    func openTerminalWithPassword(_ password: String) {
        connectionInitiator.openTerminalWithPassword(password)
    }

    // MARK: - Edit Actions

    func editConnection(_ connection: Connection) {
        connectionToEdit = connection
        isShowingEditConnectionSheet = true
    }

    func duplicateConnection(_ connection: Connection) async {
        let newConnection = Connection(
            name: "\(connection.name) Copy",
            host: connection.host,
            port: connection.port,
            username: connection.username,
            authMethod: connection.authMethod,
            privateKeyPath: connection.privateKeyPath,
            savePassword: connection.savePassword,
            description: connection.description,
            tags: connection.tags,
            iconName: connection.iconName,
            folderId: connection.folderId,
            connectionType: connection.connectionType,
            s3Region: connection.s3Region,
            s3Bucket: connection.s3Bucket,
            s3Endpoint: connection.s3Endpoint
        )

        // Copy password if saved
        if connection.savePassword, let password = keychainService.getPassword(for: connection.id) {
            await saveConnection(newConnection, password: password)
        } else {
            await saveConnection(newConnection, password: nil)
        }
    }

    // MARK: - UI Actions

    func confirmDeleteFolder(_ folder: Folder) {
        folderToDelete = folder
        isShowingDeleteFolderAlert = true
    }

    func cancelDeleteFolder() {
        folderToDelete = nil
        isShowingDeleteFolderAlert = false
    }

    func clearError() {
        error = nil
    }

    func getSavedPassword(for connection: Connection) -> String? {
        keychainService.getPassword(for: connection.id)
    }
}
