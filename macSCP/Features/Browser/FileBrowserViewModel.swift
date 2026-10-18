//
//  FileBrowserViewModel.swift
//  macSCP
//
//  ViewModel for the file browser feature.
//
//  v1.3 coordinator architecture: the VM owns @Observable state and delegates
//  all I/O-heavy workflows to five coordinators (connection lifecycle, navigation,
//  file operations, transfers, window actions). Coordinators are created lazily
//  and call back into the VM via [weak self] closures so no retain cycle forms.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FileBrowserViewModel {
    // MARK: - Published State
    private(set) var files: [RemoteFile] = []
    private(set) var state: ViewState<Void> = .idle
    private(set) var currentPath: String = "/"
    private(set) var isConnected: Bool = false
    var error: AppError?

    // Transfer progress state forwarded to TransferManager
    var isShowingTransfersPopover: Bool = false
    var hasActiveTransfers: Bool { transferManager.hasActiveTransfers }
    var activeTransferCount: Int { transferManager.activeTransferCount }
    var allTransfers: [TransferProgress] { transferManager.allTransfers }
    var overallProgress: Double { transferManager.overallProgress }
    var totalTransferSpeed: String? { transferManager.totalTransferSpeed }
    var recentTransfers: [TransferProgress] { transferManager.recentTransfers }

    var selectedFiles: Set<UUID> = []
    var sortCriteria: RemoteFile.SortCriteria = .name
    var sortAscending: Bool = true
    var showHiddenFiles: Bool = false

    // Sheet + window state
    var isShowingNewFolderSheet = false
    var isShowingNewFileSheet = false
    var isShowingRenameSheet = false
    var isShowingDeleteConfirmation = false
    var isShowingHostKeyMismatchAlert = false
    var fileToRename: RemoteFile?
    var filesToDelete: [RemoteFile] = []
    var pendingFileInfoWindowId: String?
    var pendingEditorWindowId: String?

    /// Set by TabManager when this tab is created — routes terminal requests
    /// back to the manager so the terminal opens as a sibling tab.
    @ObservationIgnored var onOpenTerminal: ((Connection, String) -> Void)?

    // MARK: - Connection Info & Dependencies
    let connection: Connection
    private let password: String
    private let sftpSession: SFTPSessionProtocol?
    private let s3Session: S3SessionProtocol?
    private let fileRepository: FileRepositoryProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let windowManager: any WindowManagerProtocol
    private let navigationService: any NavigationServiceProtocol

    // MARK: - Coordinators (lazy, [weak self] callbacks)
    @ObservationIgnored private lazy var transferManager: TransferManager = {
        TransferManager(
            fileRepository: fileRepository, connection: connection,
            onFilesChanged: { [weak self] in await self?.loadFiles() },
            onError: { [weak self] error in self?.error = error },
            onTransferPopover: { [weak self] show in self?.isShowingTransfersPopover = show }
        )
    }()

    @ObservationIgnored private lazy var fileOpsCoordinator: FileOperationsCoordinator = {
        FileOperationsCoordinator(
            fileRepository: fileRepository, clipboardService: clipboardService, connection: connection,
            onFilesChanged: { [weak self] in await self?.loadFiles() },
            onError: { [weak self] error in self?.error = error },
            getCurrentPath: { [weak self] in self?.currentPath ?? "/" },
            getSelectedFilesList: { [weak self] in self?.selectedFilesList ?? [] }
        )
    }()

    @ObservationIgnored private lazy var navigationCoordinator: BrowserNavigationCoordinator = {
        BrowserNavigationCoordinator(
            fileRepository: fileRepository, connection: connection, navigationService: navigationService,
            resolveCurrentPath: { [weak self] in
                self?.connection.connectionType == .s3
                    ? await self?.s3Session?.currentPath ?? "/"
                    : await self?.sftpSession?.currentPath ?? "/"
            }
        )
    }()

    @ObservationIgnored private lazy var windowActionCoordinator: WindowActionCoordinator = {
        WindowActionCoordinator(connection: connection, password: password, windowManager: windowManager)
    }()

    @ObservationIgnored private lazy var connectionLifecycleCoordinator: ConnectionLifecycleCoordinator = {
        ConnectionLifecycleCoordinator(
            connection: connection, sftpSession: sftpSession, s3Session: s3Session, password: password
        )
    }()

    // MARK: - Initialization (SFTP)
    init(
        connection: Connection,
        sftpSession: SFTPSessionProtocol,
        fileRepository: FileRepositoryProtocol,
        clipboardService: ClipboardServiceProtocol,
        windowManager: any WindowManagerProtocol,
        navigationService: (any NavigationServiceProtocol)? = nil,
        password: String
    ) {
        self.connection = connection
        self.sftpSession = sftpSession
        self.s3Session = nil
        self.fileRepository = fileRepository
        self.clipboardService = clipboardService
        self.windowManager = windowManager
        self.navigationService = navigationService ?? NavigationService()
        self.password = password
    }

    // MARK: - Initialization (S3)
    init(
        connection: Connection,
        s3Session: S3SessionProtocol,
        fileRepository: FileRepositoryProtocol,
        clipboardService: ClipboardServiceProtocol,
        windowManager: any WindowManagerProtocol,
        navigationService: (any NavigationServiceProtocol)? = nil,
        secretAccessKey: String
    ) {
        self.connection = connection
        self.sftpSession = nil
        self.s3Session = s3Session
        self.fileRepository = fileRepository
        self.clipboardService = clipboardService
        self.windowManager = windowManager
        self.navigationService = navigationService ?? NavigationService()
        self.password = secretAccessKey
    }

    // MARK: - Computed Properties

    var sortedFiles: [RemoteFile] {
        let visible = showHiddenFiles ? files : files.filter { !$0.isHidden }
        return RemoteFile.sortedFiles(visible, by: sortCriteria, ascending: sortAscending)
    }

    var selectedFilesList: [RemoteFile] {
        files.filter { selectedFiles.contains($0.id) }
    }

    var canGoBack: Bool { navigationCoordinator.canGoBack() }
    var canGoForward: Bool { navigationCoordinator.canGoForward() }
    var canGoUp: Bool { currentPath != "/" }
    var pathComponents: [PathComponent] { PathComponent.breadcrumbs(from: currentPath) }
    var clipboardDisplayText: String { clipboardService.displayText }
    var hasClipboardItems: Bool { !clipboardService.isEmpty }
    var canPaste: Bool { clipboardService.canPaste(to: connection.id) }

    // MARK: - Connection Lifecycle

    func connect() async {
        state = .loading
        await apply(await connectionLifecycleCoordinator.connect())
    }

    func disconnect() async {
        await connectionLifecycleCoordinator.disconnect()
        isConnected = false
        files = []
        currentPath = "/"
        navigationCoordinator.resetHistory()
    }

    func disconnectAfterHostKeyMismatch() {
        isShowingHostKeyMismatchAlert = false
        state = .idle
    }

    func replaceHostKeyAndConnect() async {
        isShowingHostKeyMismatchAlert = false
        state = .loading
        await apply(await connectionLifecycleCoordinator.replaceHostKeyAndConnect())
    }

    /// Applies a connection outcome to this VM's @Observable state.
    private func apply(_ outcome: ConnectionOutcome) async {
        switch outcome {
        case .connected(let path):
            isConnected = true
            currentPath = path
            navigationCoordinator.resetHistory(to: path)
            await loadFiles()
        case .hostKeyMismatch:
            isShowingHostKeyMismatchAlert = true
            state = .idle
        case .error(let appError):
            state = .error(appError)
        }
    }

    // MARK: - Navigation

    func loadFiles() async {
        state = .loading
        applyListResult(await navigationCoordinator.list(at: currentPath), commitHistory: false, clearSelection: false)
    }

    func navigateTo(_ path: String) async {
        state = .loading
        applyListResult(await navigationCoordinator.list(at: path), commitHistory: true, clearSelection: true)
    }

    func openFile(_ file: RemoteFile) async {
        // Non-directory files are opened in the editor by the view layer.
        guard file.isDirectory else { return }
        await navigateTo(file.path)
    }

    func goBack() async {
        if let previousPath = navigationCoordinator.backPath() {
            await navigateWithoutHistory(to: previousPath)
        }
    }

    func goForward() async {
        if let nextPath = navigationCoordinator.forwardPath() {
            await navigateWithoutHistory(to: nextPath)
        }
    }

    func goUp() async { await navigateTo(currentPath.parentPath) }
    func goHome() async { await navigateTo("~") }
    func refresh() async { await loadFiles() }

    private func navigateWithoutHistory(to path: String) async {
        state = .loading
        applyListResult(await navigationCoordinator.list(at: path), commitHistory: false, clearSelection: true)
    }

    /// Applies a file-listing result, optionally committing history and clearing selection.
    private func applyListResult(
        _ result: Result<FileListResult, AppError>, commitHistory: Bool, clearSelection: Bool
    ) {
        switch result {
        case .success(let listResult):
            files = listResult.files
            currentPath = listResult.resolvedPath
            if commitHistory { navigationCoordinator.commitNavigation(currentPath) }
            if clearSelection { selectedFiles.removeAll() }
            state = .success(())
        case .failure(let error):
            state = .error(error)
        }
    }

    // MARK: - File Operations

    func createFolder(name: String) async {
        if await fileOpsCoordinator.createFolder(name: name) { isShowingNewFolderSheet = false }
    }

    func createFile(name: String) async {
        if await fileOpsCoordinator.createFile(name: name) { isShowingNewFileSheet = false }
    }

    func renameFile(_ file: RemoteFile, to newName: String) async {
        if await fileOpsCoordinator.renameFile(file, to: newName) {
            isShowingRenameSheet = false
            fileToRename = nil
        }
    }

    func deleteFiles(_ files: [RemoteFile]) async {
        if await fileOpsCoordinator.deleteFiles(files) {
            isShowingDeleteConfirmation = false
            filesToDelete = []
            selectedFiles.removeAll()
        }
    }

    func deleteSelectedFiles() async { await deleteFiles(selectedFilesList) }

    // MARK: - Clipboard Operations

    func copySelectedFiles() { fileOpsCoordinator.copySelectedFiles() }
    func cutSelectedFiles() { fileOpsCoordinator.cutSelectedFiles() }
    func paste() async { await fileOpsCoordinator.paste() }

    // MARK: - Download / Upload

    func downloadFile(_ file: RemoteFile) async { await transferManager.downloadFile(file) }
    func downloadSelectedFiles() async { await transferManager.downloadSelectedFiles(selectedFilesList: selectedFilesList) }
    func uploadFiles() async { await transferManager.uploadFiles(at: currentPath) }
    func uploadDroppedFiles(_ urls: [URL]) async { await transferManager.uploadDroppedFiles(urls, at: currentPath) }
    func cancelTransfer(_ transfer: TransferProgress) { transferManager.cancelTransfer(transfer) }
    func cancelAllTransfers() { transferManager.cancelAllTransfers() }
    func downloadFileForPreview(_ file: RemoteFile, to url: URL) async throws {
        try await transferManager.downloadFileForPreview(file, to: url)
    }
    func downloadFileToURL(_ file: RemoteFile, destinationURL: URL) async throws {
        try await transferManager.downloadFileToURL(file, destinationURL: destinationURL)
    }
    func clearCompletedTransfers() { transferManager.clearCompletedTransfers() }
    func removeTransfer(_ transfer: TransferProgress) { transferManager.removeTransfer(transfer) }

    // MARK: - File Content

    func getFileContent(_ file: RemoteFile) async throws -> String {
        try await fileRepository.readFileContent(at: file.path)
    }

    func saveFileContent(_ content: String, to path: String) async throws {
        try await fileRepository.writeFileContent(content, to: path)
    }

    // MARK: - Selection

    func selectAll() { selectedFiles = Set(sortedFiles.map { $0.id }) }
    func deselectAll() { selectedFiles.removeAll() }

    func toggleSelection(for file: RemoteFile) {
        if selectedFiles.contains(file.id) { selectedFiles.remove(file.id) } else { selectedFiles.insert(file.id) }
    }

    // MARK: - UI Actions

    func confirmDelete(_ files: [RemoteFile]) { filesToDelete = files; isShowingDeleteConfirmation = true }
    func confirmDeleteSelected() { confirmDelete(selectedFilesList) }
    func startRename(_ file: RemoteFile) { fileToRename = file; isShowingRenameSheet = true }

    func showFileInfo(_ file: RemoteFile) {
        pendingFileInfoWindowId = windowActionCoordinator.fileInfoWindowId(for: file)
    }

    func clearPendingFileInfoWindow() { pendingFileInfoWindowId = nil }

    func openEditor(for file: RemoteFile, content: String) {
        pendingEditorWindowId = windowActionCoordinator.editorWindowId(for: file, content: content)
    }

    func clearPendingEditorWindow() { pendingEditorWindowId = nil }

    // MARK: - Terminal

    func openTerminal() {
        onOpenTerminal?(connection, password)
    }

    // MARK: - Error

    func clearError() { error = nil }
}
