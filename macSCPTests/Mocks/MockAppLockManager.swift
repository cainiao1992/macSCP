//
//  MockAppLockManager.swift
//  macSCPTests
//
//  Mock implementation of AppLockManagerProtocol for testing
//

import Foundation
@testable import macSCP

@MainActor
final class MockAppLockManager: AppLockManagerProtocol {
    // MARK: - State
    var isLocked = false
    var isAuthenticating = false
    var authenticationError: String?

    // MARK: - Preferences
    var isBiometricLockEnabled = false
    var lockOnAppResume = false
    var lockBeforeConnection = false
    var lockAfterInactivity = false
    var inactivityTimeout: InactivityTimeout = .fiveMinutes

    // MARK: - Recorded Calls
    var lockIfNeededCalled = false
    var unlockCalled = false
    var authenticateForConnectionCalled = false
    var authenticateForConnectionResult = true
    var enableBiometricLockCalled = false
    var disableBiometricLockCalled = false
    var disableBiometricLockResult = true
    var recordActivityCalled = false

    // MARK: - Protocol Implementation

    func lockIfNeeded() {
        lockIfNeededCalled = true
    }

    func unlock() {
        unlockCalled = true
        isLocked = false
    }

    func authenticateForConnection() async -> Bool {
        authenticateForConnectionCalled = true
        return authenticateForConnectionResult
    }

    func enableBiometricLock() {
        enableBiometricLockCalled = true
        isBiometricLockEnabled = true
    }

    @discardableResult
    func disableBiometricLock() async -> Bool {
        disableBiometricLockCalled = true
        isBiometricLockEnabled = false
        return disableBiometricLockResult
    }

    func recordActivity() {
        recordActivityCalled = true
    }

    // MARK: - Reset

    func reset() {
        isLocked = false
        isAuthenticating = false
        authenticationError = nil
        isBiometricLockEnabled = false
        lockOnAppResume = false
        lockBeforeConnection = false
        lockAfterInactivity = false
        inactivityTimeout = .fiveMinutes
        lockIfNeededCalled = false
        unlockCalled = false
        authenticateForConnectionCalled = false
        authenticateForConnectionResult = true
        enableBiometricLockCalled = false
        disableBiometricLockCalled = false
        disableBiometricLockResult = true
        recordActivityCalled = false
    }
}
