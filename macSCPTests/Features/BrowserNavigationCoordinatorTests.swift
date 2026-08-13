//
//  BrowserNavigationCoordinatorTests.swift
//  macSCPTests
//
//  Unit tests for BrowserNavigationCoordinator — proves independent testability
//  of the navigation logic extracted in Phase 10 (Plan 03).
//

import XCTest
@testable import macSCP

@MainActor
final class BrowserNavigationCoordinatorTests: XCTestCase {
    var sut: BrowserNavigationCoordinator!
    var mockFileRepository: MockFileRepository!
    var mockNavigationService: MockNavigationService!
    var resolvedPath: String!

    let sftpConnection = Connection(
        name: "SFTP Server",
        host: "sftp.example.com",
        username: "user",
        connectionType: .sftp
    )

    let sampleFiles = [
        RemoteFile(name: "a.txt", path: "/home/user/a.txt", isDirectory: false, size: 100, permissions: "-rw-r--r--"),
        RemoteFile(name: "docs", path: "/home/user/docs", isDirectory: true, size: 0, permissions: "drwxr-xr-x"),
    ]

    override func setUp() async throws {
        try await super.setUp()
        mockFileRepository = MockFileRepository()
        await mockFileRepository.reset()
        mockNavigationService = MockNavigationService()
        mockNavigationService.resetMock()
        resolvedPath = "/home/user"

        sut = BrowserNavigationCoordinator(
            fileRepository: mockFileRepository,
            connection: sftpConnection,
            navigationService: mockNavigationService,
            resolveCurrentPath: { [weak self] in self?.resolvedPath ?? "/" }
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFileRepository = nil
        mockNavigationService = nil
        try await super.tearDown()
    }

    // MARK: - Independent Instantiation

    func testCanBeInstantiatedWithMockDeps() {
        XCTAssertNotNil(sut)
    }

    // MARK: - list (success)

    func testList_SuccessReturnsFilesAndResolvedPath() async {
        mockFileRepository.mockFiles = sampleFiles

        let result = await sut.list(at: "/home/user")

        switch result {
        case .success(let listing):
            XCTAssertEqual(listing.files.count, 2)
            XCTAssertEqual(listing.resolvedPath, "/home/user")
        case .failure:
            XCTFail("Expected success")
        }
        XCTAssertTrue(mockFileRepository.listFilesCalled)
        XCTAssertEqual(mockFileRepository.lastListPath, "/home/user")
    }

    // MARK: - list (failure)

    func testList_FailureWrapsError() async {
        mockFileRepository.mockError = AppError.sftpOperationFailed("Permission denied")

        let result = await sut.list(at: "/home/user")

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            guard case .sftpOperationFailed = error else {
                return XCTFail("Expected sftpOperationFailed")
            }
        }
    }

    // MARK: - History delegation

    func testCanGoBack_DelegatesToNavigationService() {
        XCTAssertFalse(sut.canGoBack())
        mockNavigationService.navigate(to: "/home/user")
        mockNavigationService.navigate(to: "/home/user/docs")
        XCTAssertTrue(sut.canGoBack())
    }

    func testCanGoForward_DelegatesToNavigationService() {
        XCTAssertFalse(sut.canGoForward())
    }

    func testBackPath_NavigatesViaService() {
        mockNavigationService.navigate(to: "/home/user")
        mockNavigationService.navigate(to: "/home/user/docs")

        let path = sut.backPath()

        XCTAssertEqual(path, "/home/user")
        XCTAssertTrue(mockNavigationService.goBackCalled)
    }

    func testForwardPath_NavigatesViaService() {
        mockNavigationService.navigate(to: "/home/user")
        mockNavigationService.navigate(to: "/home/user/docs")
        _ = mockNavigationService.goBack()

        let path = sut.forwardPath()

        XCTAssertEqual(path, "/home/user/docs")
        XCTAssertTrue(mockNavigationService.goForwardCalled)
    }

    func testCommitNavigation_CallsService() {
        sut.commitNavigation("/home/user")

        XCTAssertTrue(mockNavigationService.navigateCalled)
        XCTAssertEqual(mockNavigationService.lastNavigatedPath, "/home/user")
    }

    func testResetHistoryToPath_CallsServiceWithPath() {
        sut.resetHistory(to: "/home/user")

        XCTAssertTrue(mockNavigationService.resetCalled)
        XCTAssertEqual(mockNavigationService.lastResetPath, "/home/user")
    }

    func testResetHistory_CallsServiceReset() {
        sut.resetHistory()

        XCTAssertTrue(mockNavigationService.resetCalled)
    }
}
