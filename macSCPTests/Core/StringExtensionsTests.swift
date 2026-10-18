//
//  StringExtensionsTests.swift
//  macSCPTests
//
//  Unit tests for String+Extensions
//

import XCTest
@testable import macSCP

@MainActor
final class StringExtensionsTests: XCTestCase {

    // MARK: - trimmed

    func testTrimmed_RemovesWhitespace() {
        XCTAssertEqual("  hello  ".trimmed, "hello")
        XCTAssertEqual("\t\nhello\t\n".trimmed, "hello")
    }

    func testTrimmed_NoWhitespace() {
        XCTAssertEqual("hello".trimmed, "hello")
    }

    func testTrimmed_EmptyString() {
        XCTAssertEqual("".trimmed, "")
    }

    // MARK: - isBlank

    func testIsBlank_Empty() {
        XCTAssertTrue("".isBlank)
    }

    func testIsBlank_WhitespaceOnly() {
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("\t\n".isBlank)
    }

    func testIsBlank_NotBlank() {
        XCTAssertFalse("hello".isBlank)
        XCTAssertFalse(" a ".isBlank)
    }

    // MARK: - fileName

    func testFileName_FromPath() {
        XCTAssertEqual("/path/to/file.txt".fileName, "file.txt")
        XCTAssertEqual("file.txt".fileName, "file.txt")
    }

    func testFileName_DirectoryPath() {
        XCTAssertEqual("/path/to/folder/".fileName, "folder")
        XCTAssertEqual("/path/to/folder".fileName, "folder")
    }

    // MARK: - directoryPath

    func testDirectoryPath_FromFullPath() {
        XCTAssertEqual("/path/to/file.txt".directoryPath, "/path/to")
    }

    func testDirectoryPath_RootFile() {
        XCTAssertEqual("/file.txt".directoryPath, "/")
    }

    // MARK: - fileExtension

    func testFileExtension_WithExtension() {
        XCTAssertEqual("file.txt".fileExtension, "txt")
        XCTAssertEqual("file.tar.gz".fileExtension, "gz")
    }

    func testFileExtension_NoExtension() {
        XCTAssertEqual("Makefile".fileExtension, "")
    }

    // MARK: - fileNameWithoutExtension

    func testFileNameWithoutExtension() {
        XCTAssertEqual("file.txt".fileNameWithoutExtension, "file")
        XCTAssertEqual("archive.tar.gz".fileNameWithoutExtension, "archive.tar")
    }

    func testFileNameWithoutExtension_NoExtension() {
        XCTAssertEqual("Makefile".fileNameWithoutExtension, "Makefile")
    }

    // MARK: - appendingPathComponent

    func testAppendingPathComponent() {
        let result = "/path/to".appendingPathComponent("file.txt")
        XCTAssertTrue(result.hasPrefix("/path/to"))
        XCTAssertTrue(result.hasSuffix("file.txt"))
    }

    // MARK: - parentPath

    func testParentPath_NestedFile() {
        XCTAssertEqual("/path/to/file.txt".parentPath, "/path/to")
    }

    func testParentPath_RootFile() {
        XCTAssertEqual("/file.txt".parentPath, "/")
    }

    func testParentPath_DeepPath() {
        XCTAssertEqual("/a/b/c/d".parentPath, "/a/b/c")
    }

    // MARK: - normalizedPath

    func testNormalizedPath_RemovesTrailingSlash() {
        XCTAssertEqual("/path/to/".normalizedPath, "/path/to")
    }

    func testNormalizedPath_NoTrailingSlash() {
        XCTAssertEqual("/path/to".normalizedPath, "/path/to")
    }

    func testNormalizedPath_ResolvesDot() {
        XCTAssertEqual("/path/./to".normalizedPath, "/path/to")
    }

    func testNormalizedPath_ResolvesDotDot() {
        XCTAssertEqual("/path/to/../from".normalizedPath, "/path/from")
    }

    // MARK: - isChildOf

    func testIsChildOf_True() {
        XCTAssertTrue("/path/to/file.txt".isChildOf("/path/to"))
        XCTAssertTrue("/path/to/sub/file.txt".isChildOf("/path/to"))
    }

    func testIsChildOf_False() {
        XCTAssertFalse("/path/to/file.txt".isChildOf("/other/path"))
        XCTAssertFalse("/path/to".isChildOf("/path/to"))
    }

    // MARK: - relativePath

    func testRelativePath_FromBase() {
        XCTAssertEqual("/path/to/file.txt".relativePath(from: "/path/to"), "file.txt")
        XCTAssertEqual("/path/to/sub/file.txt".relativePath(from: "/path/to"), "sub/file.txt")
    }

    func testRelativePath_SamePath() {
        XCTAssertEqual("/path/to".relativePath(from: "/path/to"), ".")
    }

    // MARK: - resolvingPath

    func testResolvingPath_RelativeToAbsolute() {
        XCTAssertEqual("/path/to".resolvingPath("file.txt"), "/path/to/file.txt")
    }

    func testResolvingPath_AlreadyAbsolute() {
        XCTAssertEqual("/path/to".resolvingPath("/other/file.txt"), "/other/file.txt")
    }

    func testResolvingPath_DotDot() {
        XCTAssertEqual("/path/to".resolvingPath("../file.txt"), "/path/file.txt")
    }
}
