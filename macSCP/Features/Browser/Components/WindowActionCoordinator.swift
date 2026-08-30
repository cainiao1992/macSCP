//
//  WindowActionCoordinator.swift
//  macSCP
//
//  Coordinates opening secondary windows (file info, editor, terminal) from the
//  file browser. Extracted from FileBrowserViewModel for independent testability.
//

import Foundation

@MainActor
final class WindowActionCoordinator {
    // MARK: - Dependencies
    private let connection: Connection
    private let password: String
    private let windowManager: any WindowManagerProtocol

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) that occurs when a @MainActor class with
    // stored @escaping closures is deallocated (Swift 6.2 runtime bug).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        connection: Connection,
        password: String,
        windowManager: any WindowManagerProtocol
    ) {
        self.connection = connection
        self.password = password
        self.windowManager = windowManager
    }

    // MARK: - File Info

    func fileInfoWindowId(for file: RemoteFile) -> String {
        let data = FileInfoWindowData(
            file: file,
            connectionName: connection.name
        )
        let windowId = windowManager.storeFileInfoData(data)
        AnalyticsService.track(.fileInfoOpened)
        return windowId
    }

    // MARK: - Editor

    func editorWindowId(for file: RemoteFile, content: String) -> String {
        let data = FileEditorWindowData(
            filePath: file.path,
            fileName: file.name,
            content: content,
            connectionId: connection.id,
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: password,
            authMethod: connection.authMethod,
            privateKeyPath: connection.privateKeyPath,
            connectionType: connection.connectionType,
            s3Region: connection.s3Region,
            s3Bucket: connection.s3Bucket,
            s3Endpoint: connection.s3Endpoint
        )
        let windowId = windowManager.storeFileEditorData(data)
        AnalyticsService.trackEditorOpened(fileExtension: (file.name as NSString).pathExtension)
        return windowId
    }
}
