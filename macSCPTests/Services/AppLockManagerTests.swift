//
//  AppLockManagerTests.swift
//  macSCPTests
//
//  Unit tests for AppLockManager
//

import XCTest
@testable import macSCP

@MainActor
final class AppLockManagerTests: XCTestCase {
    private var manager: AppLockManager!
    private var mockBiometric: MockBiometricAuthService!

    private let userDefaultsKeys = [
        "com.macSCP.biometricLockEnabled",
        "com.macSCP.lockOnAppResume",
        "com.macSCP.lockBeforeConnection",
        "com.macSCP.lockAfterInactivity",
        "com.macSCP.inactivityTimeout"
    ]

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        clearUserDefaults()
        mockBiometric = MockBiometricAuthService()
        manager = AppLockManager(biometricService: mockBiometric)
    }

    override func tearDown() async throws {
        clearUserDefaults()
        manager = nil
        mockBiometric = nil
        try await super.tearDown()
    }

    private func clearUserDefaults() {
        userDefaultsKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - InactivityTimeout Enum Tests

    func testInactivityTimeout_OneMinute() {
        XCTAssertEqual(InactivityTimeout.oneMinute.rawValue, 60)
        XCTAssertEqual(InactivityTimeout.oneMinute.label, "1 minute")
    }

    func testInactivityTimeout_FiveMinutes() {
        XCTAssertEqual(InactivityTimeout.fiveMinutes.rawValue, 300)
        XCTAssertEqual(InactivityTimeout.fiveMinutes.label, "5 minutes")
    }

    func testInactivityTimeout_FifteenMinutes() {
        XCTAssertEqual(InactivityTimeout.fifteenMinutes.rawValue, 900)
        XCTAssertEqual(InactivityTimeout.fifteenMinutes.label, "15 minutes")
    }

    func testInactivityTimeout_ThirtyMinutes() {
        XCTAssertEqual(InactivityTimeout.thirtyMinutes.rawValue, 1800)
        XCTAssertEqual(InactivityTimeout.thirtyMinutes.label, "30 minutes")
    }

    func testInactivityTimeout_OneHour() {
        XCTAssertEqual(InactivityTimeout.oneHour.rawValue, 3600)
        XCTAssertEqual(InactivityTimeout.oneHour.label, "1 hour")
    }

    func testInactivityTimeout_AllCasesHaveNonEmptyLabels() {
        for timeout in InactivityTimeout.allCases {
            XCTAssertFalse(timeout.label.isEmpty, "InactivityTimeout.\(timeout) should have non-empty label")
        }
    }

    func testInactivityTimeout_CaseIterableCount() {
        XCTAssertEqual(InactivityTimeout.allCases.count, 5)
    }

    // MARK: - Lock Gating Tests

    func testLockIfNeeded_WhenBiometricLockDisabled_StaysUnlocked() {
        XCTAssertFalse(manager.isBiometricLockEnabled)

        manager.lockIfNeeded()

        XCTAssertFalse(manager.isLocked)
    }

    func testLockIfNeeded_WhenBiometricLockEnabled_BecomesLocked() {
        manager.enableBiometricLock()
        XCTAssertTrue(manager.isBiometricLockEnabled)

        manager.lockIfNeeded()

        XCTAssertTrue(manager.isLocked)
    }

    // MARK: - Enable / Disable Tests

    func testEnableBiometricLock_SetsEnabled() {
        manager.enableBiometricLock()
        XCTAssertTrue(manager.isBiometricLockEnabled)
    }

    func testDisableBiometricLock_WhenAuthSucceeds_DisablesLock() async {
        manager.enableBiometricLock()
        mockBiometric.mockResult = .success(())

        let result = await manager.disableBiometricLock()

        XCTAssertTrue(result)
        XCTAssertFalse(manager.isBiometricLockEnabled)
    }

    func testDisableBiometricLock_WhenAuthFails_StaysEnabled() async {
        manager.enableBiometricLock()
        mockBiometric.mockResult = .failure(.authenticationFailed("test"))

        let result = await manager.disableBiometricLock()

        XCTAssertFalse(result)
        XCTAssertTrue(manager.isBiometricLockEnabled)
    }

    // MARK: - authenticateForConnection Tests

    func testAuthenticateForConnection_WhenBiometricLockDisabled_ReturnsTrue() async {
        XCTAssertFalse(manager.isBiometricLockEnabled)

        let result = await manager.authenticateForConnection()

        XCTAssertTrue(result)
    }

    func testAuthenticateForConnection_WhenLockBeforeConnectionDisabled_ReturnsTrue() async {
        manager.enableBiometricLock()
        XCTAssertFalse(manager.lockBeforeConnection)

        let result = await manager.authenticateForConnection()

        XCTAssertTrue(result)
    }

    func testAuthenticateForConnection_WhenEnabledAndAuthSucceeds_ReturnsTrue() async {
        manager.enableBiometricLock()
        manager.lockBeforeConnection = true
        mockBiometric.mockResult = .success(())

        let result = await manager.authenticateForConnection()

        XCTAssertTrue(result)
        XCTAssertFalse(manager.isLocked)
    }

    func testAuthenticateForConnection_WhenEnabledAndAuthFails_ReturnsFalse() async {
        manager.enableBiometricLock()
        manager.lockBeforeConnection = true
        mockBiometric.mockResult = .failure(.authenticationFailed("test"))

        let result = await manager.authenticateForConnection()

        XCTAssertFalse(result)
    }

    // MARK: - UserDefaults Persistence Tests

    func testLockOnAppResume_DefaultIsFalse() {
        XCTAssertFalse(manager.lockOnAppResume)
    }

    func testLockBeforeConnection_DefaultIsFalse() {
        XCTAssertFalse(manager.lockBeforeConnection)
    }

    func testLockAfterInactivity_DefaultIsFalse() {
        XCTAssertFalse(manager.lockAfterInactivity)
    }

    func testInactivityTimeout_DefaultIsFiveMinutes() {
        XCTAssertEqual(manager.inactivityTimeout, .fiveMinutes)
    }

    // MARK: - State Consistency Tests

    func testRecordActivity_WhenNotLocked_DoesNotCrash() {
        manager.enableBiometricLock()
        manager.recordActivity()
    }

    func testRecordActivity_WhenLocked_DoesNotCrash() {
        manager.enableBiometricLock()
        manager.lockIfNeeded()
        XCTAssertTrue(manager.isLocked)

        manager.recordActivity()
    }

    // MARK: - Fresh Instance Isolation

    func testFreshInstance_StartsUnlocked() {
        let fresh = AppLockManager(biometricService: mockBiometric)
        XCTAssertFalse(fresh.isLocked)
        XCTAssertFalse(fresh.isBiometricLockEnabled)
    }
}
