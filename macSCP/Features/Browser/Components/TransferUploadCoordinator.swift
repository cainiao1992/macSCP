//
//  TransferUploadCoordinator.swift
//  macSCP
//
//  Owns all upload paths (files, single file, recursive directory, dropped files).
//  Mutates TransferManager's transfer state via the injected TransferStateRegistry,
//  keeping TransferManager the single source of truth. Extracted from
//  TransferManager for independent testability (VM-SPLIT-01).
//
//  ERROR-01: the recursive createDirectory failure inside uploadDirectory is now
//  routed through AppError.from with an explicit best-effort comment — no silent
//  bare catch remains.
//

import Foundation
import SwiftUI

@MainActor
final class TransferUploadCoordinator {
    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let connection: Connection
    private let registry: TransferStateRegistry
    private let onTransferPopover: (Bool) -> Void
    private let onFilesChanged: () async -> Void
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
        onFilesChanged: @escaping () async -> Void,
        onError: @escaping (AppError) -> Void
    ) {
        self.fileRepository = fileRepository
        self.connection = connection
        self.registry = registry
        self.onTransferPopover = onTransferPopover
        self.onFilesChanged = onFilesChanged
        self.onError = onError
    }

    // MARK: - Upload

    func uploadFiles(at currentPath: String) async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        await uploadURLs(panel.urls, at: currentPath)
    }

    /// Uploads files dropped from Finder into the current directory
    func uploadDroppedFiles(_ urls: [URL], at currentPath: String) async {
        await uploadURLs(urls, at: currentPath)
    }

    /// Core upload method that handles multiple files/directories with parallel progress tracking
    private func uploadURLs(_ urls: [URL], at currentPath: String) async {
        let validURLs = urls.filter { $0.isFileURL }
        guard !validURLs.isEmpty else { return }

        onTransferPopover(true)

        let maxConcurrent = 4

        for url in validURLs {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                // Upload directory recursively
                await uploadDirectory(url, toRemotePath: currentPath)
            } else {
                // Upload single file
                await uploadSingleFile(url, maxConcurrent: maxConcurrent, at: currentPath)
            }
        }

        await onFilesChanged()
    }

    /// Uploads a single file with transfer tracking
    private func uploadSingleFile(_ url: URL, maxConcurrent: Int, at currentPath: String) async {
        let remotePath = currentPath.appendingPathComponent(url.lastPathComponent)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let transferId = UUID()
        let transfer = TransferProgress(
            id: transferId,
            fileName: url.lastPathComponent,
            localURL: url,
            remotePath: remotePath,
            bytesTransferred: 0,
            totalBytes: fileSize,
            transferType: .upload,
            status: .inProgress
        )
        registry.register(transfer)

        let uploadTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                try Task.checkCancellation()

                try await self.fileRepository.upload(localURL: url, to: remotePath) { bytesTransferred in
                    Task { @MainActor [weak self] in
                        self?.registry.updateProgress(transferId, bytesTransferred)
                    }
                }

                try Task.checkCancellation()

                await MainActor.run {
                    self.registry.complete(transferId, fileSize)
                }

                AnalyticsService.trackFileUploaded(protocol: .init(from: self.connection.connectionType), fileCount: 1, totalBytes: fileSize)
                logInfo("Uploaded: \(url.lastPathComponent)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)

            } catch {
                let isCancellation = error is CancellationError ||
                    Task.isCancelled ||
                    String(describing: error).contains("CancellationError")

                if isCancellation {
                    await MainActor.run {
                        self.registry.cancel(transferId)
                    }
                    logInfo("Upload cancelled: \(url.lastPathComponent)", category: self.connection.connectionType == .s3 ? .s3 : .sftp)
                } else {
                    await MainActor.run {
                        self.registry.fail(transferId, error.localizedDescription)
                    }

                    logError("Upload failed: \(AppError.from(error))", category: self.connection.connectionType == .s3 ? .s3 : .sftp)
                    await MainActor.run {
                        self.onError(AppError.from(error))
                    }
                }
            }
        }

        registry.trackTask(transferId, uploadTask)
        await uploadTask.value
    }

    /// Recursively uploads a directory
    private func uploadDirectory(_ directoryURL: URL, toRemotePath remoteBase: String) async {
        let dirName = directoryURL.lastPathComponent
        let remoteDirPath = remoteBase.appendingPathComponent(dirName)

        // Create the top-level remote directory. A failure here aborts the whole
        // directory upload — it is surfaced to the user via onError.
        do {
            try await fileRepository.createDirectory(at: remoteDirPath)
        } catch {
            onError(AppError.from(error))
            logError("Failed to create remote directory: \(AppError.from(error))", category: connection.connectionType == .s3 ? .s3 : .sftp)
            return
        }

        // Enumerate local directory contents
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let itemURL as URL in enumerator {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            let isFile = resourceValues?.isRegularFile ?? false
            let isDir = resourceValues?.isDirectory ?? false

            // Calculate relative path from the original directory
            let relativePath = itemURL.path.replacingOccurrences(
                of: directoryURL.deletingLastPathComponent().path + "/",
                with: ""
            )
            let remotePath = remoteBase.appendingPathComponent(relativePath)

            if isDir {
                // Best-effort: a nested directory may already exist on the remote
                // during recursive upload, so a collision is expected — classify
                // the error via AppError.from for consistent ERROR-01 handling
                // while keeping the diagnostic log (no silent bare catch).
                do {
                    try await fileRepository.createDirectory(at: remotePath)
                } catch {
                    logError("Best-effort mkdir failed for \(relativePath) (directory may already exist): \(AppError.from(error))", category: connection.connectionType == .s3 ? .s3 : .sftp)
                }
            } else if isFile {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: itemURL.path)[.size] as? Int64) ?? 0

                let transferId = UUID()
                let transfer = TransferProgress(
                    id: transferId,
                    fileName: relativePath,
                    localURL: itemURL,
                    remotePath: remotePath,
                    bytesTransferred: 0,
                    totalBytes: fileSize,
                    transferType: .upload,
                    status: .inProgress
                )
                registry.register(transfer)

                do {
                    try await fileRepository.upload(localURL: itemURL, to: remotePath) { bytesTransferred in
                        Task { @MainActor [weak self] in
                            self?.registry.updateProgress(transferId, bytesTransferred)
                        }
                    }

                    registry.complete(transferId, fileSize)

                    logInfo("Uploaded: \(relativePath)", category: connection.connectionType == .s3 ? .s3 : .sftp)
                } catch {
                    registry.fail(transferId, error.localizedDescription)
                    logError("Upload failed for \(relativePath): \(AppError.from(error))", category: connection.connectionType == .s3 ? .s3 : .sftp)
                    // Continue with other files even if one fails
                }
            }
        }
    }
}
