//
//  ConnectionCRUDCoordinator.swift
//  macSCP
//
//  Coordinates connection CRUD operations (save/update/delete/move)
//  Extracted from ConnectionListViewModel for independent testability
//

import Foundation

@MainActor
final class ConnectionCRUDCoordinator {
    // MARK: - Dependencies
    private let connectionRepository: ConnectionRepositoryProtocol
    private let keychainService: KeychainServiceProtocol
    private let onReloadData: () async -> Void
    private let onError: (AppError) -> Void
    private let onConnectionMoved: (Connection, UUID?) -> Void

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) on @MainActor classes that store @escaping closures
    // (Swift 6.2 runtime bug — same workaround as TransferManager / FileOperationsCoordinator).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        connectionRepository: ConnectionRepositoryProtocol,
        keychainService: KeychainServiceProtocol,
        onReloadData: @escaping () async -> Void,
        onError: @escaping (AppError) -> Void,
        onConnectionMoved: @escaping (Connection, UUID?) -> Void
    ) {
        self.connectionRepository = connectionRepository
        self.keychainService = keychainService
        self.onReloadData = onReloadData
        self.onError = onError
        self.onConnectionMoved = onConnectionMoved
    }

    // MARK: - CRUD Operations

    func saveConnection(_ connection: Connection, password: String?) async -> Bool {
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

            await onReloadData()
            AnalyticsService.trackConnectionCreated(protocol: .init(from: connection.connectionType))
            logInfo("Connection saved: \(connection.name)", category: .database)
            return true
        } catch {
            logError("Failed to save connection: \(error)", category: .database)
            onError(AppError.from(error))
            return false
        }
    }

    func updateConnection(_ connection: Connection, password: String?) async -> Bool {
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

            await onReloadData()
            AnalyticsService.track(.connectionEdited, with: [
                "protocol": AnalyticsService.ConnectionProtocol(from: connection.connectionType).rawValue
            ])
            logInfo("Connection updated: \(connection.name)", category: .database)
            return true
        } catch {
            logError("Failed to update connection: \(error)", category: .database)
            onError(AppError.from(error))
            return false
        }
    }

    func deleteConnection(_ connection: Connection) async -> Bool {
        do {
            try await connectionRepository.delete(id: connection.id)
            // Delete credentials based on connection type
            if connection.connectionType == .s3 {
                try? keychainService.deleteS3Credentials(for: connection.id)
            } else {
                try? keychainService.deletePassword(for: connection.id)
            }
            await onReloadData()
            AnalyticsService.track(.connectionDeleted, with: [
                "protocol": AnalyticsService.ConnectionProtocol(from: connection.connectionType).rawValue
            ])
            logInfo("Connection deleted: \(connection.name)", category: .database)
            return true
        } catch {
            logError("Failed to delete connection: \(error)", category: .database)
            onError(AppError.from(error))
            return false
        }
    }

    func moveConnection(_ connection: Connection, to folder: Folder?) async -> Bool {
        do {
            try await connectionRepository.move(connectionId: connection.id, toFolderId: folder?.id)
            // Update local state directly to avoid .loading flash
            onConnectionMoved(connection, folder?.id)
            logInfo("Connection moved: \(connection.name)", category: .database)
            return true
        } catch {
            logError("Failed to move connection: \(error)", category: .database)
            onError(AppError.from(error))
            return false
        }
    }
}
