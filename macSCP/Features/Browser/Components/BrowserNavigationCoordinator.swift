//
//  BrowserNavigationCoordinator.swift
//  macSCP
//
//  Coordinates file listing and path navigation (history, back/forward/up/home).
//  Extracted from FileBrowserViewModel for independent testability.
//

import Foundation

/// Result of a successful file listing — pairs the listed files with the
/// authoritative path resolved by the session (S3 and SFTP differ here).
struct FileListResult: Sendable {
    let files: [RemoteFile]
    let resolvedPath: String
}

@MainActor
final class BrowserNavigationCoordinator {
    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let connection: Connection
    private let navigationService: any NavigationServiceProtocol
    private let resolveCurrentPath: () async -> String

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        fileRepository: FileRepositoryProtocol,
        connection: Connection,
        navigationService: any NavigationServiceProtocol,
        resolveCurrentPath: @escaping () async -> String
    ) {
        self.fileRepository = fileRepository
        self.connection = connection
        self.navigationService = navigationService
        self.resolveCurrentPath = resolveCurrentPath
    }

    // MARK: - Listing

    /// Lists files at `path` and resolves the authoritative current path
    /// (S3 and SFTP report the path differently).
    func list(at path: String) async -> Result<FileListResult, AppError> {
        do {
            let files = try await fileRepository.listFiles(at: path)
            let resolvedPath = await resolveCurrentPath()
            return .success(FileListResult(files: files, resolvedPath: resolvedPath))
        } catch {
            logError("Failed to list files at \(path): \(error)", category: connection.connectionType == .s3 ? .s3 : .sftp)
            return .failure(AppError.from(error))
        }
    }

    // MARK: - History

    func canGoBack() -> Bool { navigationService.canGoBack }

    func canGoForward() -> Bool { navigationService.canGoForward }

    func backPath() -> String? { navigationService.goBack() }

    func forwardPath() -> String? { navigationService.goForward() }

    func commitNavigation(_ path: String) {
        navigationService.navigate(to: path)
    }

    func resetHistory(to path: String) {
        navigationService.reset(to: path)
    }

    func resetHistory() {
        navigationService.reset()
    }
}
