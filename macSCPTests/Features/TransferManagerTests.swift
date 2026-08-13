//
//  TransferManagerTests.swift
//  macSCPTests
//
//  Unit tests for TransferManager — proves independent testability (VM-SPLIT-03)
//

import XCTest
@testable import macSCP

@MainActor
final class TransferManagerTests: XCTestCase {
    var sut: TransferManager!
    var mockFileRepository: MockFileRepository!

    let testConnection = Connection(
        name: "Test Server",
        host: "test.example.com",
        username: "testuser"
    )

    override func setUp() async throws {
        try await super.setUp()
        mockFileRepository = MockFileRepository()
        await mockFileRepository.reset()

        sut = TransferManager(
            fileRepository: mockFileRepository,
            connection: testConnection,
            onFilesChanged: {},
            onError: { _ in },
            onTransferPopover: { _ in }
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFileRepository = nil
        try await super.tearDown()
    }

    // MARK: - Independent Instantiation (VM-SPLIT-03)

    func testTransferManager_CanBeInstantiatedWithMockDeps() {
        // Then — proves the component is independently instantiable
        XCTAssertNotNil(sut)
        XCTAssertTrue(sut.activeTransfers.isEmpty)
        XCTAssertTrue(sut.recentTransfers.isEmpty)
    }

    // MARK: - hasActiveTransfers

    func testHasActiveTransfers_FalseInitially_TrueAfterPopulation() {
        // Initially false
        XCTAssertFalse(sut.hasActiveTransfers)

        // After population
        let id = UUID()
        sut.activeTransfers[id] = TransferProgress(
            fileName: "test.txt",
            totalBytes: 100,
            transferType: .download
        )
        XCTAssertTrue(sut.hasActiveTransfers)
    }

    // MARK: - activeTransferCount

    func testActiveTransferCount_MatchesDictionaryCount() {
        XCTAssertEqual(sut.activeTransferCount, 0)

        sut.activeTransfers[UUID()] = TransferProgress(fileName: "a.txt", totalBytes: 100)
        sut.activeTransfers[UUID()] = TransferProgress(fileName: "b.txt", totalBytes: 200)
        XCTAssertEqual(sut.activeTransferCount, 2)
    }

    // MARK: - allTransfers

    func testAllTransfers_ActiveSortedByStartTimeDescendingThenRecent() {
        let earlier = Date(timeIntervalSinceReferenceDate: 100)
        let later = Date(timeIntervalSinceReferenceDate: 200)

        sut.activeTransfers[UUID()] = TransferProgress(
            fileName: "earlier.txt",
            totalBytes: 100,
            startTime: earlier
        )
        sut.activeTransfers[UUID()] = TransferProgress(
            fileName: "later.txt",
            totalBytes: 200,
            startTime: later
        )
        sut.recentTransfers.append(TransferProgress(
            fileName: "recent.txt",
            totalBytes: 50,
            status: .completed
        ))

        let result = sut.allTransfers

        // Active transfers sorted by startTime descending (later first)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].fileName, "later.txt")
        XCTAssertEqual(result[1].fileName, "earlier.txt")
        // Recent transfers follow
        XCTAssertEqual(result[2].fileName, "recent.txt")
    }

    // MARK: - overallProgress

    func testOverallProgress_ZeroWhenEmpty_CorrectRatioWhenTransfersExist() {
        // Empty → 0
        XCTAssertEqual(sut.overallProgress, 0)

        // Two transfers: 50/100 + 25/100 = 75/200 = 0.375
        let id1 = UUID()
        let id2 = UUID()
        sut.activeTransfers[id1] = TransferProgress(
            fileName: "a.txt",
            bytesTransferred: 50,
            totalBytes: 100
        )
        sut.activeTransfers[id2] = TransferProgress(
            fileName: "b.txt",
            bytesTransferred: 25,
            totalBytes: 100
        )

        XCTAssertEqual(sut.overallProgress, 0.375, accuracy: 0.001)
    }
}
