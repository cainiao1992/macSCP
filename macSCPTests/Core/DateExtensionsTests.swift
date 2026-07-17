//
//  DateExtensionsTests.swift
//  macSCPTests
//
//  Unit tests for Date+Extensions
//

import XCTest
@testable import macSCP

@MainActor
final class DateExtensionsTests: XCTestCase {

    // MARK: - relativeTimeString

    func testRelativeTimeString_JustNow() {
        let date = Date()
        let str = date.relativeTimeString
        XCTAssertFalse(str.isEmpty)
    }

    func testRelativeTimeString_MinutesAgo() {
        let date = Date().addingTimeInterval(-120)
        let str = date.relativeTimeString
        XCTAssertFalse(str.isEmpty)
    }

    func testRelativeTimeString_HoursAgo() {
        let date = Date().addingTimeInterval(-7200)
        let str = date.relativeTimeString
        XCTAssertFalse(str.isEmpty)
    }

    func testRelativeTimeString_DaysAgo() {
        let date = Date().addingTimeInterval(-172800)
        let str = date.relativeTimeString
        XCTAssertFalse(str.isEmpty)
    }

    // MARK: - iso8601String

    func testIso8601String_Format() {
        let date = Date(timeIntervalSince1970: 0)
        let str = date.iso8601String
        XCTAssertTrue(str.contains("1970"))
        XCTAssertTrue(str.contains("T"))
    }

    // MARK: - from(unixTimestamp:)

    func testFromUnixTimestamp_Zero() {
        let date = Date.from(unixTimestamp: 0)
        XCTAssertEqual(date.timeIntervalSince1970, 0)
    }

    func testFromUnixTimestamp_Positive() {
        let date = Date.from(unixTimestamp: 1700000000)
        XCTAssertEqual(date.timeIntervalSince1970, 1700000000)
    }

    // MARK: - from(iso8601String:)

    func testFromIso8601String_Valid() {
        let date = Date.from(iso8601String: "2024-01-15T10:30:00.123Z")
        XCTAssertNotNil(date)
    }

    func testFromIso8601String_WithoutFractionalSeconds() {
        let date = Date.from(iso8601String: "2024-01-15T10:30:00Z")
        XCTAssertNil(date)
    }

    func testFromIso8601String_Invalid() {
        let date = Date.from(iso8601String: "not-a-date")
        XCTAssertNil(date)
    }

    // MARK: - fileListDisplayString

    func testFileListDisplayString_Today() {
        let date = Date()
        let str = date.fileListDisplayString
        XCTAssertTrue(str.hasPrefix("Today"))
        XCTAssertFalse(str.isEmpty)
    }

    func testFileListDisplayString_Yesterday() {
        let date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let str = date.fileListDisplayString
        XCTAssertTrue(str.hasPrefix("Yesterday"))
    }

    func testFileListDisplayString_OldDate() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let str = date.fileListDisplayString
        XCTAssertFalse(str.isEmpty)
    }

    // MARK: - fileInfoDisplayString

    func testFileInfoDisplayString() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let str = date.fileInfoDisplayString
        XCTAssertFalse(str.isEmpty)
    }

    func testFileInfoDisplayString_NotEmpty() {
        let date = Date()
        let str = date.fileInfoDisplayString
        XCTAssertFalse(str.isEmpty)
    }
}
