//
//  MockBiometricAuthService.swift
//  macSCPTests
//
//  Mock implementation of BiometricAuthServiceProtocol for testing
//

import Foundation
@testable import macSCP

@MainActor
final class MockBiometricAuthService: BiometricAuthServiceProtocol {
    // MARK: - State
    var isAvailable = true
    var mockResult: Result<Void, BiometricError> = .success(())

    // MARK: - Recorded Calls
    var authenticateCalled = false
    var lastReason: String?

    // MARK: - Protocol Implementation

    func isBiometricAvailable() -> Bool {
        isAvailable
    }

    func authenticate(reason: String) async -> Result<Void, BiometricError> {
        authenticateCalled = true
        lastReason = reason
        return mockResult
    }

    // MARK: - Reset

    func reset() {
        isAvailable = true
        mockResult = .success(())
        authenticateCalled = false
        lastReason = nil
    }
}
