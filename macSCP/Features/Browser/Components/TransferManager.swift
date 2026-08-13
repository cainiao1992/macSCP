//
//  TransferManager.swift
//  macSCP
//
//  Manages file transfer operations (download/upload/cancel/progress)
//  Extracted from FileBrowserViewModel for independent testability
//

import Foundation
import SwiftUI

/// Mutation entry points into TransferManager's transfer state.
///
/// Download/upload coordinators call these instead of touching the
/// dictionaries directly, keeping TransferManager the single source of truth
/// (activeTransfers/recentTransfers/transferTasks). The closures capture
/// TransferManager weakly, so the coordinator (owned by TransferManager via a
/// lazy var) never forms a retain cycle.
struct TransferStateRegistry {
    /// Register a new active transfer.
    let register: (TransferProgress) -> Void
    /// Update byte progress for an active transfer.
    let updateProgress: (UUID, Int64) -> Void
    /// Mark a transfer completed: remove from active, set `.completed` + final
    /// byte count, move to recent (capped at 50), drop its task.
    let complete: (UUID, Int64) -> Void
    /// Mark a transfer cancelled: remove from active, set `.cancelled`, move to
    /// recent, drop its task.
    let cancel: (UUID) -> Void
    /// Mark a transfer failed: remove from active, set `.failed` + message, move
    /// to recent (left uncapped to match the original fail paths), drop its task.
    let fail: (UUID, String) -> Void
    /// Track a transfer's Task so it can be cancelled.
    let trackTask: (UUID, Task<Void, Never>) -> Void
    /// Remove a finished transfer's task.
    let removeTask: (UUID) -> Void
}

@MainActor
@Observable
final class TransferManager {
    // MARK: - State
    var activeTransfers: [UUID: TransferProgress] = [:]
    var recentTransfers: [TransferProgress] = []
    var transferTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Computed Properties

    /// Whether any transfer is currently in progress
    var hasActiveTransfers: Bool {
        !activeTransfers.isEmpty
    }

    /// Total number of active transfers
    var activeTransferCount: Int {
        activeTransfers.count
    }

    /// All transfers for display (active + recent)
    var allTransfers: [TransferProgress] {
        let active = activeTransfers.values.sorted { $0.startTime > $1.startTime }
        return active + recentTransfers
    }

    /// Overall progress of all active transfers (0.0 to 1.0)
    var overallProgress: Double {
        guard !activeTransfers.isEmpty else { return 0 }
        let totalBytes = activeTransfers.values.reduce(0) { $0 + $1.totalBytes }
        let transferredBytes = activeTransfers.values.reduce(0) { $0 + $1.bytesTransferred }
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    /// Total transfer speed across all active transfers formatted as display string
    var totalTransferSpeed: String? {
        guard !activeTransfers.isEmpty else { return nil }
        let totalSpeed = activeTransfers.values.reduce(0.0) { $0 + $1.transferSpeed }
        guard totalSpeed > 0 else { return nil }
        return "\(ByteCountFormatter.string(fromByteCount: Int64(totalSpeed), countStyle: .file))/s"
    }

    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let connection: Connection
    private let onFilesChanged: () async -> Void
    private let onError: (AppError) -> Void
    private let onTransferPopover: (Bool) -> Void

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        fileRepository: FileRepositoryProtocol,
        connection: Connection,
        onFilesChanged: @escaping () async -> Void,
        onError: @escaping (AppError) -> Void,
        onTransferPopover: @escaping (Bool) -> Void
    ) {
        self.fileRepository = fileRepository
        self.connection = connection
        self.onFilesChanged = onFilesChanged
        self.onError = onError
        self.onTransferPopover = onTransferPopover
    }

    // MARK: - Coordinators
    @ObservationIgnored private lazy var transferDownloadCoordinator: TransferDownloadCoordinator = {
        TransferDownloadCoordinator(
            fileRepository: fileRepository,
            connection: connection,
            registry: makeTransferStateRegistry(),
            onTransferPopover: { [weak self] show in self?.onTransferPopover(show) },
            onError: { [weak self] error in self?.onError(error) }
        )
    }()

    @ObservationIgnored private lazy var transferUploadCoordinator: TransferUploadCoordinator = {
        TransferUploadCoordinator(
            fileRepository: fileRepository,
            connection: connection,
            registry: makeTransferStateRegistry(),
            onTransferPopover: { [weak self] show in self?.onTransferPopover(show) },
            onFilesChanged: { [weak self] in await self?.onFilesChanged() },
            onError: { [weak self] error in self?.onError(error) }
        )
    }()

    /// Builds the registry of state-mutation closures handed to the download/upload
    /// coordinators. Closures capture `self` weakly so coordinators (owned here via
    /// lazy vars) never retain TransferManager.
    private func makeTransferStateRegistry() -> TransferStateRegistry {
        TransferStateRegistry(
            register: { [weak self] transfer in
                self?.activeTransfers[transfer.id] = transfer
            },
            updateProgress: { [weak self] id, bytes in
                self?.activeTransfers[id]?.bytesTransferred = bytes
            },
            complete: { [weak self] id, finalBytes in
                guard let self else { return }
                if var completed = self.activeTransfers.removeValue(forKey: id) {
                    completed.status = .completed
                    completed.bytesTransferred = finalBytes
                    self.recentTransfers.insert(completed, at: 0)
                    self.capRecentTransfers()
                }
                self.transferTasks.removeValue(forKey: id)
            },
            cancel: { [weak self] id in
                guard let self else { return }
                if var cancelled = self.activeTransfers.removeValue(forKey: id) {
                    cancelled.status = .cancelled
                    self.recentTransfers.insert(cancelled, at: 0)
                }
                self.transferTasks.removeValue(forKey: id)
            },
            fail: { [weak self] id, errorMessage in
                guard let self else { return }
                if var failed = self.activeTransfers.removeValue(forKey: id) {
                    failed.status = .failed
                    failed.error = errorMessage
                    self.recentTransfers.insert(failed, at: 0)
                }
                self.transferTasks.removeValue(forKey: id)
            },
            trackTask: { [weak self] id, task in
                self?.transferTasks[id] = task
            },
            removeTask: { [weak self] id in
                self?.transferTasks.removeValue(forKey: id)
            }
        )
    }

    /// Caps the recent-transfers list at 50 entries (oldest dropped first).
    private func capRecentTransfers() {
        if recentTransfers.count > 50 {
            recentTransfers = Array(recentTransfers.prefix(50))
        }
    }

    // MARK: - Download (delegates)

    func downloadFile(_ file: RemoteFile) async {
        await transferDownloadCoordinator.downloadFile(file)
    }

    func downloadSelectedFiles(selectedFilesList: [RemoteFile]) async {
        await transferDownloadCoordinator.downloadSelectedFiles(selectedFilesList: selectedFilesList)
    }

    /// Downloads a file to a temp URL for Quick Look preview (no transfer tracking)
    func downloadFileForPreview(_ file: RemoteFile, to url: URL) async throws {
        try await transferDownloadCoordinator.downloadFileForPreview(file, to: url)
    }

    /// Downloads a file or directory to a specific URL (used for drag-out file promises)
    func downloadFileToURL(_ file: RemoteFile, destinationURL: URL) async throws {
        try await transferDownloadCoordinator.downloadFileToURL(file, destinationURL: destinationURL)
    }

    // MARK: - Upload (delegates)

    func uploadFiles(at currentPath: String) async {
        await transferUploadCoordinator.uploadFiles(at: currentPath)
    }

    /// Uploads files dropped from Finder into the current directory
    func uploadDroppedFiles(_ urls: [URL], at currentPath: String) async {
        await transferUploadCoordinator.uploadDroppedFiles(urls, at: currentPath)
    }

    // MARK: - Cancel

    /// Cancels an active transfer
    func cancelTransfer(_ transfer: TransferProgress) {
        guard transfer.isInProgress else { return }

        // Cancel the task
        if let task = transferTasks[transfer.id] {
            task.cancel()
        }

        // Immediately update UI to show cancelled state
        if var cancelledTransfer = activeTransfers.removeValue(forKey: transfer.id) {
            cancelledTransfer.status = .cancelled
            recentTransfers.insert(cancelledTransfer, at: 0)
        }
        transferTasks.removeValue(forKey: transfer.id)
    }

    /// Cancels all active transfers
    func cancelAllTransfers() {
        for (id, task) in transferTasks {
            task.cancel()
            if var cancelledTransfer = activeTransfers.removeValue(forKey: id) {
                cancelledTransfer.status = .cancelled
                recentTransfers.insert(cancelledTransfer, at: 0)
            }
        }
        transferTasks.removeAll()
    }

    // MARK: - Transfer List Management

    /// Clears completed/failed transfers from the list
    func clearCompletedTransfers() {
        recentTransfers.removeAll()
    }

    /// Removes a specific transfer from the recent list
    func removeTransfer(_ transfer: TransferProgress) {
        recentTransfers.removeAll { $0.id == transfer.id }
    }
}
