//
//  EnvironmentKeys.swift
//  macSCP
//
//  SwiftUI EnvironmentKey definitions for dependency-injected services and
//  factory closures. Views/Windows consume these via @Environment instead of
//  reaching into singletons directly, keeping the composition root (MacSCPApp)
//  as the only place that wires the DependencyContainer.
//
//  NOTE on @Observable tracking: AppLockManager and WindowManager are injected
//  as their CONCRETE types (not `any Protocol`) because SwiftUI's @Observable /
//  ObservableObject change tracking requires the concrete type. The protocols
//  (AppLockManagerProtocol / WindowManagerProtocol) are used for VM-level
//  injection only.
//

import SwiftUI

// MARK: - Service EnvironmentKeys

/// AppLockManager — concrete type for @Observable change tracking.
private struct AppLockManagerEnvironmentKey: EnvironmentKey {
    @MainActor
    static var defaultValue: AppLockManager { AppLockManager.shared }
}

/// WindowManager — concrete type for ObservableObject change tracking.
private struct WindowManagerEnvironmentKey: EnvironmentKey {
    @MainActor
    static var defaultValue: WindowManager { WindowManager.shared }
}

/// BiometricAuthService — used by SettingsView for availability checks only
/// (no change tracking required, so the protocol existential is fine).
private struct BiometricAuthServiceEnvironmentKey: EnvironmentKey {
    static var defaultValue: any BiometricAuthServiceProtocol { BiometricAuthService.shared }
}

extension EnvironmentValues {
    var appLockManager: AppLockManager {
        get { self[AppLockManagerEnvironmentKey.self] }
        set { self[AppLockManagerEnvironmentKey.self] = newValue }
    }

    var windowManager: WindowManager {
        get { self[WindowManagerEnvironmentKey.self] }
        set { self[WindowManagerEnvironmentKey.self] = newValue }
    }

    var biometricService: any BiometricAuthServiceProtocol {
        get { self[BiometricAuthServiceEnvironmentKey.self] }
        set { self[BiometricAuthServiceEnvironmentKey.self] = newValue }
    }
}

// MARK: - Factory-closure EnvironmentKeys
//
// Specific factory closures are injected (NOT the whole DependencyContainer) to
// avoid the service-locator anti-pattern. Each Window receives only the
// capabilities it needs. Closures are created at the composition root
// (MacSCPApp) and encapsulate container access. Defaults reach for
// DependencyContainer.shared solely as a fallback for previews.

private struct MakeFileBrowserViewModelKey: EnvironmentKey {
    static var defaultValue: (Connection, any SFTPSessionProtocol, String) -> FileBrowserViewModel {
        { connection, sftpSession, password in
            DependencyContainer.shared.makeFileBrowserViewModel(
                connection: connection, sftpSession: sftpSession, password: password
            )
        }
    }
}

private struct MakeS3FileBrowserViewModelKey: EnvironmentKey {
    static var defaultValue: (Connection, any S3SessionProtocol, String) -> FileBrowserViewModel {
        { connection, s3Session, secretAccessKey in
            DependencyContainer.shared.makeS3FileBrowserViewModel(
                connection: connection, s3Session: s3Session, secretAccessKey: secretAccessKey
            )
        }
    }
}

private struct MakeS3SessionKey: EnvironmentKey {
    static var defaultValue: () -> any S3SessionProtocol {
        { DependencyContainer.shared.makeS3Session() }
    }
}

private struct MakeSFTPSessionKey: EnvironmentKey {
    static var defaultValue: (String?) -> any SFTPSessionProtocol {
        { privateKeyPath in DependencyContainer.shared.makeSFTPSession(privateKeyPath: privateKeyPath) }
    }
}

private struct MakeFileEditorDependenciesKey: EnvironmentKey {
    static var defaultValue: (FileEditorWindowData) async throws -> (FileRepositoryProtocol, S3SessionProtocol?, SFTPSessionProtocol?) {
        { try await DependencyContainer.shared.makeFileEditorDependencies(for: $0) }
    }
}

private struct MakeTerminalSessionKey: EnvironmentKey {
    static var defaultValue: (TerminalWindowData) -> TerminalSessionProtocol {
        { DependencyContainer.shared.makeTerminalSession(connectionData: $0) }
    }
}

private struct MakeTerminalViewModelKey: EnvironmentKey {
    static var defaultValue: (String, TerminalSessionProtocol, TerminalWindowData) -> TerminalViewModel {
        { connectionName, session, connectionData in
            DependencyContainer.shared.makeTerminalViewModel(
                connectionName: connectionName, session: session, connectionData: connectionData
            )
        }
    }
}

extension EnvironmentValues {
    var makeFileBrowserViewModel: (Connection, any SFTPSessionProtocol, String) -> FileBrowserViewModel {
        get { self[MakeFileBrowserViewModelKey.self] }
        set { self[MakeFileBrowserViewModelKey.self] = newValue }
    }

    var makeS3FileBrowserViewModel: (Connection, any S3SessionProtocol, String) -> FileBrowserViewModel {
        get { self[MakeS3FileBrowserViewModelKey.self] }
        set { self[MakeS3FileBrowserViewModelKey.self] = newValue }
    }

    var makeS3Session: () -> any S3SessionProtocol {
        get { self[MakeS3SessionKey.self] }
        set { self[MakeS3SessionKey.self] = newValue }
    }

    var makeSFTPSession: (String?) -> any SFTPSessionProtocol {
        get { self[MakeSFTPSessionKey.self] }
        set { self[MakeSFTPSessionKey.self] = newValue }
    }

    var makeFileEditorDependencies: (FileEditorWindowData) async throws -> (FileRepositoryProtocol, S3SessionProtocol?, SFTPSessionProtocol?) {
        get { self[MakeFileEditorDependenciesKey.self] }
        set { self[MakeFileEditorDependenciesKey.self] = newValue }
    }

    var makeTerminalSession: (TerminalWindowData) -> TerminalSessionProtocol {
        get { self[MakeTerminalSessionKey.self] }
        set { self[MakeTerminalSessionKey.self] = newValue }
    }

    var makeTerminalViewModel: (String, TerminalSessionProtocol, TerminalWindowData) -> TerminalViewModel {
        get { self[MakeTerminalViewModelKey.self] }
        set { self[MakeTerminalViewModelKey.self] = newValue }
    }
}
