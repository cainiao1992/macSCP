//
//  ConnectionInitiator.swift
//  macSCP
//
//  Coordinates connection/terminal initiation (biometric auth gate + credential lookup)
//  Extracted from ConnectionListViewModel for independent testability
//

import Foundation

@MainActor
final class ConnectionInitiator {
    // MARK: - Dependencies
    private let keychainService: KeychainServiceProtocol
    private let tabManager: TabManager
    private let appLockManager: any AppLockManagerProtocol
    private let getConnectionToConnect: () -> Connection?
    private let onSetConnectionToConnect: (Connection?) -> Void
    private let onShowPasswordPrompt: (Bool) -> Void

    // MARK: - Deinit
    // nonisolated deinit avoids the swift_task_deinitOnExecutorMainActorBackDeploy
    // memory-corruption crash (SIGABRT) on @MainActor classes that store @escaping closures
    // (Swift 6.2 runtime bug — same workaround as TransferManager / FileOperationsCoordinator).
    nonisolated deinit {}

    // MARK: - Initialization
    init(
        keychainService: KeychainServiceProtocol,
        tabManager: TabManager,
        appLockManager: any AppLockManagerProtocol,
        getConnectionToConnect: @escaping () -> Connection?,
        onSetConnectionToConnect: @escaping (Connection?) -> Void,
        onShowPasswordPrompt: @escaping (Bool) -> Void
    ) {
        self.keychainService = keychainService
        self.tabManager = tabManager
        self.appLockManager = appLockManager
        self.getConnectionToConnect = getConnectionToConnect
        self.onSetConnectionToConnect = onSetConnectionToConnect
        self.onShowPasswordPrompt = onShowPasswordPrompt
    }

    // MARK: - Connection Operations

    func connectToServer(_ connection: Connection) {
        logInfo("Connect requested for: \(connection.name)", category: .ui)

        Task { @MainActor in
            // Gate connection behind biometric auth if configured
            let allowed = await self.appLockManager.authenticateForConnection()
            guard allowed else {
                logInfo("Connection cancelled: biometric auth denied", category: .auth)
                return
            }

            onSetConnectionToConnect(connection)

            if connection.connectionType == .s3 {
                // For S3, check for saved credentials
                if let credentials = keychainService.getS3Credentials(for: connection.id) {
                    logInfo("Found saved S3 credentials, opening browser", category: .ui)
                    openFileBrowser(for: connection, password: credentials.secretAccessKey)
                } else {
                    logInfo("No saved S3 credentials, showing prompt", category: .ui)
                    onShowPasswordPrompt(true)
                }
            } else {
                // For SFTP, check for saved password
                if let savedPassword = keychainService.getPassword(for: connection.id) {
                    logInfo("Found saved password, opening browser", category: .ui)
                    openFileBrowser(for: connection, password: savedPassword)
                } else if connection.authMethod == .privateKey {
                    // Key-based auth doesn't require a password — connect directly
                    logInfo("Private key auth, connecting without password", category: .ui)
                    openFileBrowser(for: connection, password: "")
                } else {
                    logInfo("No saved password, showing prompt", category: .ui)
                    onShowPasswordPrompt(true)
                }
            }
        }
    }

    private func openFileBrowser(for connection: Connection, password: String) {
        tabManager.openTab(connection: connection, password: password)
        AnalyticsService.trackConnectionConnected(protocol: .init(from: connection.connectionType), success: true)
        logInfo("Opened tab for connection: \(connection.name)", category: .ui)
    }

    // MARK: - Password-Based Connection

    func connectWithPassword(_ password: String) {
        guard let connection = getConnectionToConnect() else { return }
        openFileBrowser(for: connection, password: password)
        onShowPasswordPrompt(false)
        onSetConnectionToConnect(nil)
    }

    // MARK: - Terminal Operations

    func openTerminal(for connection: Connection, password: String) {
        tabManager.openTerminalTab(connection: connection, password: password)
        logInfo("Opened terminal tab for connection: \(connection.name)", category: .ui)
    }

    func requestTerminal(for connection: Connection) {
        if connection.connectionType == .s3 {
            logWarning("Terminal not supported for S3 connections", category: .ui)
            return
        }

        Task { @MainActor in
            // Gate terminal behind biometric auth if configured
            let allowed = await self.appLockManager.authenticateForConnection()
            guard allowed else {
                logInfo("Terminal cancelled: biometric auth denied", category: .auth)
                return
            }

            onSetConnectionToConnect(connection)

            // Check for saved password
            if let savedPassword = keychainService.getPassword(for: connection.id) {
                openTerminal(for: connection, password: savedPassword)
            } else if connection.authMethod == .privateKey {
                // Key-based auth doesn't require a password — connect directly
                logInfo("Private key auth, opening terminal without password", category: .ui)
                openTerminal(for: connection, password: "")
            } else {
                // Need to prompt for password
                onShowPasswordPrompt(true)
            }
        }
    }

    func openTerminalWithPassword(_ password: String) {
        guard let connection = getConnectionToConnect() else { return }
        openTerminal(for: connection, password: password)
        onShowPasswordPrompt(false)
        onSetConnectionToConnect(nil)
    }
}
