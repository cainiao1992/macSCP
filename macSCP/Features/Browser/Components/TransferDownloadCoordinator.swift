//
//  TransferDownloadCoordinator.swift
//  macSCP
//
//  Owns all download paths (single file, selected files, Quick Look, drag-out).
//  Mutates TransferManager's transfer state via the injected TransferStateRegistry,
//  keeping TransferManager the single source of truth. Extracted from
//  TransferManager for independent testability (VM-SPLIT-01).
//

import Foundation
import SwiftUI

@MainActor
final class TransferDownloadCoordinator {
    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let connection: Connection
    private let registry: TransferStateRegistry
    private let onTransferPopover: (Bool) -> Void
    private let onError: (AppError) -> Void

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        fileRepository: FileRepositoryProtocol,
        connection: Connection,
        registry: TransferStateRegistry,
        onTransferPopover: @escaping (Bool) -> Void,
        onError: @escaping (AppError) -> Void
    ) {
        self.fileRepository = fileRepository
        self.connection = connection
        self.registry = registry
        self.onTransferPopover = onTransferPopover
        self.onError = onError
    }

    // MARK: - Download

    func downloadFile(_ file: RemoteFile) async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = file.name
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let transferId = UUID()
        let transfer = TransferProgress(
            id: transferId,
            fileName: file.name,
            localURL: url,
            remotePath: file.path,
            bytesTransferred: 0,
            totalBytes: file.size,
            transferType: .download,
            status: .inProgress
        )
        registry.register(transfer)
        onTransferPopover(true)

        let downloadTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                try Task.checkCancellation()

                try await self.fileRepository.download(remotePath: file.path, to: url) { bytesTransferred in
                    Task { @MainActor [weak self] in
                        self?.registry.updateProgress(transferId, bytesTransferred)
                    }
                }

                try Task.checkCancellation()

                await MainActor.run {
                    self.registry.complete(transferId, file.size)
                }

                AnalyticsService.trackFileDownloaded(protocol: .init(from: self.connection.connectionType), fileCount: 1, totalBytes: file.size)
                logInfo("Downloaded: \(file.name)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)

            } catch {
                let isCancellation = error is CancellationError ||
                    Task.isCancelled ||
                    String(describing: error).contains("CancellationError")

                if isCancellation {
                    await MainActor.run {
                        self.registry.cancel(transferId)
                    }
                    logInfo("Download cancelled: \(file.name)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)
                } else {
                    await MainActor.run {
                        self.registry.fail(transferId, error.localizedDescription)
                    }

                    logError("Download failed: \(error)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)
                    await MainActor.run {
                        self.onError(AppError.from(error))
                    }
                }
            }
        }

        registry.trackTask(transferId, downloadTask)
    }

    /// Download multiple selected files to a user-chosen directory
    func downloadSelectedFiles(selectedFilesList: [RemoteFile]) async {
        let filesToDownload = selectedFilesList.filter { $0.isFile }
        guard !filesToDownload.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Download"
        panel.message = "Choose a folder to download \(filesToDownload.count) file\(filesToDownload.count == 1 ? "" : "s")"

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        onTransferPopover(true)

        for file in filesToDownload {
            let destinationURL = directory.appendingPathComponent(file.name)
            let transferId = UUID()
            let transfer = TransferProgress(
                id: transferId,
                fileName: file.name,
                localURL: destinationURL,
                remotePath: file.path,
                bytesTransferred: 0,
                totalBytes: file.size,
                transferType: .download,
                status: .inProgress
            )
            registry.register(transfer)

            let downloadTask = Task { [weak self] in
                guard let self = self else { return }

                do {
                    try Task.checkCancellation()

                    try await self.fileRepository.download(remotePath: file.path, to: destinationURL) { bytesTransferred in
                        Task { @MainActor [weak self] in
                            self?.registry.updateProgress(transferId, bytesTransferred)
                        }
                    }

                    try Task.checkCancellation()

                    await MainActor.run {
                        self.registry.complete(transferId, file.size)
                    }

                    AnalyticsService.trackFileDownloaded(protocol: .init(from: self.connection.connectionType), fileCount: 1, totalBytes: file.size)
                    logInfo("Downloaded: \(file.name)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)
                } catch {
                    let isCancellation = error is CancellationError || Task.isCancelled || String(describing: error).contains("CancellationError")

                    if isCancellation {
                        await MainActor.run {
                            self.registry.cancel(transferId)
                        }
                    } else {
                        await MainActor.run {
                            self.registry.fail(transferId, error.localizedDescription)
                            self.onError(AppError.from(error))
                        }
                    }
                }
            }

            registry.trackTask(transferId, downloadTask)
        }
    }

    // MARK: - Quick Look

    /// Downloads a file to a temp URL for Quick Look preview (no transfer tracking)
    func downloadFileForPreview(_ file: RemoteFile, to url: URL) async throws {
        try await fileRepository.download(remotePath: file.path, to: url) { _ in }
    }

    // MARK: - Drag and Drop

    /// Downloads a file or directory to a specific URL (used for drag-out file promises)
    func downloadFileToURL(_ file: RemoteFile, destinationURL: URL) async throws {
        if file.isDirectory {
            try await downloadDirectoryToURL(file, destinationURL: destinationURL)
        } else {
            try await downloadSingleFileToURL(file, destinationURL: destinationURL)
        }
    }

    /// Downloads a single file to a specific URL with transfer tracking
    private func downloadSingleFileToURL(_ file: RemoteFile, destinationURL: URL) async throws {
        let transferId = UUID()
        let transfer = TransferProgress(
            id: transferId,
            fileName: file.name,
            localURL: destinationURL,
            remotePath: file.path,
            bytesTransferred: 0,
            totalBytes: file.size,
            transferType: .download,
            status: .inProgress
        )
        registry.register(transfer)
        onTransferPopover(true)

        do {
            try await fileRepository.download(remotePath: file.path, to: destinationURL) { bytesTransferred in
                Task { @MainActor [weak self] in
                    self?.registry.updateProgress(transferId, bytesTransferred)
                }
            }

            registry.complete(transferId, file.size)

            AnalyticsService.trackFileDownloaded(protocol: .init(from: connection.connectionType), fileCount: 1, totalBytes: file.size)
            logInfo("Downloaded via drag: \(file.name)", category: connection.connectionType == .s3 ? .s3 : .sftp)
        } catch {
            registry.fail(transferId, error.localizedDescription)
            throw error
        }
    }

    /// Recursively downloads a directory to a specific URL
    private func downloadDirectoryToURL(_ directory: RemoteFile, destinationURL: URL) async throws {
        // Create the local directory
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let contents = try await fileRepository.listFiles(at: directory.path)
        for item in contents {
            let itemDestination = destinationURL.appendingPathComponent(item.name)
            if item.isDirectory {
                try await downloadDirectoryToURL(item, destinationURL: itemDestination)
            } else {
                try await fileRepository.download(remotePath: item.path, to: itemDestination)
            }
        }
    }
}
