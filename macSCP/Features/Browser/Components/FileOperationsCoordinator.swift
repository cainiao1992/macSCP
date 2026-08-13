//
//  FileOperationsCoordinator.swift
//  macSCP
//
//  Coordinates file CRUD and clipboard operations
//  Extracted from FileBrowserViewModel for independent testability
//

import Foundation

@MainActor
final class FileOperationsCoordinator {
    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let clipboardService: ClipboardServiceProtocol
    private let connection: Connection
    private let onFilesChanged: () async -> Void
    private let onError: (AppError) -> Void
    private let getCurrentPath: () -> String
    private let getSelectedFilesList: () -> [RemoteFile]

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        fileRepository: FileRepositoryProtocol,
        clipboardService: ClipboardServiceProtocol,
        connection: Connection,
        onFilesChanged: @escaping () async -> Void,
        onError: @escaping (AppError) -> Void,
        getCurrentPath: @escaping () -> String,
        getSelectedFilesList: @escaping () -> [RemoteFile]
    ) {
        self.fileRepository = fileRepository
        self.clipboardService = clipboardService
        self.connection = connection
        self.onFilesChanged = onFilesChanged
        self.onError = onError
        self.getCurrentPath = getCurrentPath
        self.getSelectedFilesList = getSelectedFilesList
    }

    // MARK: - File Operations

    func createFolder(name: String) async -> Bool {
        let path = getCurrentPath().appendingPathComponent(name)

        do {
            try await fileRepository.createDirectory(at: path)
            AnalyticsService.trackFileOperation(.createFolder, protocol: .init(from: connection.connectionType))
            await onFilesChanged()
            return true
        } catch {
            logError("Failed to create folder: \(error)", category: .sftp)
            onError(AppError.from(error))
            return false
        }
    }

    func createFile(name: String) async -> Bool {
        let path = getCurrentPath().appendingPathComponent(name)

        do {
            try await fileRepository.createFile(at: path)
            await onFilesChanged()
            return true
        } catch {
            logError("Failed to create file: \(error)", category: .sftp)
            onError(AppError.from(error))
            return false
        }
    }

    func renameFile(_ file: RemoteFile, to newName: String) async -> Bool {
        let newPath = file.path.directoryPath.appendingPathComponent(newName)

        do {
            try await fileRepository.rename(from: file.path, to: newPath)
            AnalyticsService.trackFileOperation(.rename, protocol: .init(from: connection.connectionType))
            await onFilesChanged()
            return true
        } catch {
            logError("Failed to rename file: \(error)", category: .sftp)
            onError(AppError.from(error))
            return false
        }
    }

    func deleteFiles(_ files: [RemoteFile]) async -> Bool {
        for file in files {
            do {
                try await fileRepository.delete(at: file.path, isDirectory: file.isDirectory)
            } catch {
                logError("Failed to delete \(file.name): \(error)", category: .sftp)
                onError(AppError.from(error))
                return false
            }
        }

        AnalyticsService.trackFileOperation(.delete, protocol: .init(from: connection.connectionType), count: files.count)
        await onFilesChanged()
        return true
    }

    // MARK: - Clipboard Operations

    func copySelectedFiles() {
        clipboardService.copy(files: getSelectedFilesList(), from: getCurrentPath(), connectionId: connection.id)
    }

    func cutSelectedFiles() {
        clipboardService.cut(files: getSelectedFilesList(), from: getCurrentPath(), connectionId: connection.id)
    }

    func paste() async {
        guard clipboardService.canPaste(to: connection.id) else { return }

        let items = clipboardService.items
        let isCut = clipboardService.isCut

        for item in items {
            let destinationPath = getCurrentPath().appendingPathComponent(item.fileName)

            do {
                if isCut {
                    try await fileRepository.move(from: item.fullSourcePath, to: destinationPath)
                } else {
                    try await fileRepository.copy(
                        from: item.fullSourcePath,
                        to: destinationPath,
                        isDirectory: item.isDirectory
                    )
                }
            } catch {
                logError("Failed to paste \(item.fileName): \(error)", category: .sftp)
                onError(AppError.from(error))
                return
            }
        }

        if isCut {
            clipboardService.clear()
        }

        await onFilesChanged()
    }
}
