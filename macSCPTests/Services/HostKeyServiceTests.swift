//
//  HostKeyServiceTests.swift
//  macSCPTests
//
//  Unit tests for HostKeyService
//

import XCTest
@testable import macSCP

final class HostKeyServiceTests: XCTestCase {

    // MARK: - removeHostKey Error Handling

    func testRemoveHostKey_StandardPort_DoesNotThrow() {
        XCTAssertNoThrow(try HostKeyService.removeHostKey(host: "nonexistent.host.test", port: 22))
    }

    func testRemoveHostKey_NonStandardPort_DoesNotThrow() {
        XCTAssertNoThrow(try HostKeyService.removeHostKey(host: "nonexistent.host.test", port: 2222))
    }

    func testRemoveHostKey_InvalidHost_DoesNotThrow() {
        XCTAssertNoThrow(try HostKeyService.removeHostKey(host: "", port: 22))
    }
}
