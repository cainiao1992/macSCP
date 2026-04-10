//
//  FileRepositoryTests.swift
//  macSCPTests
//
//  Unit tests for FileRepository content preservation
//

import XCTest
@testable import macSCP

@MainActor
final class FileRepositoryTests: XCTestCase {
    var mockSession: MockSFTPSession!
    var sut: FileRepository!

    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockSFTPSession()
        await mockSession.reset()
        sut = FileRepository(sftpSession: mockSession)
    }

    override func tearDown() async throws {
        sut = nil
        mockSession = nil
        try await super.tearDown()
    }

    // MARK: - Special Character Preservation in writeFileContent

    func testWriteFileContent_SingleQuotes_Preserved() async throws {
        let content = "RUN sed -i ''s#deb.debian.org#mirrors.aliyun.com#g'' /etc/apt/sources.list.d/debian.sources &&"

        try await sut.writeFileContent(content, to: "/test/Dockerfile")

        let recorded = await mockSession.lastWriteContent
        let recordedPath = await mockSession.lastWritePath
        XCTAssertEqual(recorded, content, "Single quotes '' must be preserved, not converted to '\\''")
        XCTAssertEqual(recordedPath, "/test/Dockerfile")
    }

    func testWriteFileContent_SingleQuoteInWord_Preserved() async throws {
        let content = "it's a test\ndon't break this"

        try await sut.writeFileContent(content, to: "/test/file.txt")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_DoubleQuotes_Preserved() async throws {
        let content = "echo \"hello world\"\nprint(\"value = 42\")"

        try await sut.writeFileContent(content, to: "/test/script.sh")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_Backslashes_Preserved() async throws {
        let content = "path = C:\\Users\\test\\file.txt\nregex = \\d+\\.\\d+"

        try await sut.writeFileContent(content, to: "/test/config.txt")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_DollarSign_Preserved() async throws {
        let content = "export PATH=$HOME/bin:$PATH\necho $USER"

        try await sut.writeFileContent(content, to: "/test/env.sh")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_Backticks_Preserved() async throws {
        let content = "result=`date +%Y-%m-%d`\necho $result"

        try await sut.writeFileContent(content, to: "/test/script.sh")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_HeredocInContent_Preserved() async throws {
        let content = "cat << 'EOF'\nsome content\nEOF"

        try await sut.writeFileContent(content, to: "/test/heredoc.sh")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_MixedSpecialChars_Preserved() async throws {
        let content = """
        #!/bin/bash
        echo "it's a $VAR test"
        sed -i ''s/old/new/g'' file.conf
        PATH="C:\\test\\path"
        val=`expr 1 + 2`
        cat << 'HEREDOC'
        content with 'quotes' and $vars
        HEREDOC
        """

        try await sut.writeFileContent(content, to: "/test/mixed.sh")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_EmptyContent() async throws {
        try await sut.writeFileContent("", to: "/test/empty.txt")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, "")
    }

    func testWriteFileContent_UnicodePreserved() async throws {
        let content = "你好世界\nこんにちは\n안녕하세요\n🎉🚀"

        try await sut.writeFileContent(content, to: "/test/unicode.txt")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    func testWriteFileContent_NewlinesPreserved() async throws {
        let content = "line1\nline2\r\nline3\rline4"

        try await sut.writeFileContent(content, to: "/test/newlines.txt")

        let recorded = await mockSession.lastWriteContent
        XCTAssertEqual(recorded, content)
    }

    // MARK: - Read File Content

    func testReadFileContent_SpecialCharsPreserved() async throws {
        let expected = "it's a test with ''quotes'' and $vars"
        await mockSession.setMockFileContent(expected)

        let result = try await sut.readFileContent(at: "/test/file.txt")

        XCTAssertEqual(result, expected)
    }

    // MARK: - Error Propagation

    func testWriteFileContent_ErrorPropagated() async {
        await mockSession.setMockError(AppError.notConnected)

        do {
            try await sut.writeFileContent("test", to: "/test/file.txt")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
}
