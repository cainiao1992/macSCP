//
//  S3SessionTests.swift
//  macSCPTests
//
//  Unit tests for S3Session
//

import XCTest
@testable import macSCP

final class S3SessionTests: XCTestCase {

    // MARK: - Pagination

    func testCollectAllPages_FollowsContinuationTokenUntilComplete() async throws {
        var requestedTokens: [String?] = []
        let pages: [(items: [String], isTruncated: Bool, nextToken: String?)] = [
            (["a", "b"], true, "page-2"),
            (["c"], false, nil)
        ]

        let items = try await S3Session.collectAllPages { token in
            requestedTokens.append(token)
            return pages[requestedTokens.count - 1]
        }

        XCTAssertEqual(items, ["a", "b", "c"],
                       "Objects from every page must be collected, not just the first")
        XCTAssertEqual(requestedTokens.count, 2)
        XCTAssertNil(requestedTokens[0], "First request must not carry a continuation token")
        XCTAssertEqual(requestedTokens[1], "page-2")
    }

    func testCollectAllPages_SinglePageTerminatesAfterOneFetch() async throws {
        var fetchCount = 0

        let items = try await S3Session.collectAllPages { _ in
            fetchCount += 1
            return (["only"], false, nil)
        }

        XCTAssertEqual(items, ["only"])
        XCTAssertEqual(fetchCount, 1)
    }

    func testCollectAllPages_TruncatedWithoutTokenTerminates() async throws {
        var fetchCount = 0

        let items = try await S3Session.collectAllPages { _ in
            fetchCount += 1
            return (["a"], true, nil)
        }

        XCTAssertEqual(items, ["a"])
        XCTAssertEqual(fetchCount, 1, "A truncated page without a token cannot be followed")
    }

    func testListPageSize_StaysWithinS3SingleResponseLimit() {
        XCTAssertEqual(S3Session.listPageSize, 1000)
    }
}