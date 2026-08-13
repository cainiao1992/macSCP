//
//  AppLockManagerProtocol.swift
//  macSCP
//
//  Protocol for app lock state and biometric authentication management
//

import Foundation

@MainActor
protocol AppLockManagerProtocol: AnyObject {
    // MARK: - State
    var isLocked: Bool { get }
    var isAuthenticating: Bool { get }
    var authenticationError: String? { get }

    // MARK: - Preferences
    var isBiometricLockEnabled: Bool { get }
    var lockOnAppResume: Bool { get set }
    var lockBeforeConnection: Bool { get set }
    var lockAfterInactivity: Bool { get set }
    var inactivityTimeout: InactivityTimeout { get set }

    // MARK: - Methods
    func lockIfNeeded()
    func unlock()
    func authenticateForConnection() async -> Bool
    func enableBiometricLock()
    func disableBiometricLock() async -> Bool
    func recordActivity()
}
