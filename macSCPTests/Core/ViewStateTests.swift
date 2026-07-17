//
//  ViewStateTests.swift
//  macSCPTests
//
//  Unit tests for ViewState
//

import XCTest
@testable import macSCP

@MainActor
final class ViewStateTests: XCTestCase {

    func testIdleState() {
        let state: ViewState<String> = .idle
        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.data)
        XCTAssertNil(state.error)
    }

    func testLoadingState() {
        let state: ViewState<String> = .loading
        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertNil(state.data)
        XCTAssertNil(state.error)
    }

    func testSuccessState() {
        let state: ViewState<String> = .success("hello")
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.isSuccess)
        XCTAssertFalse(state.isError)
        XCTAssertEqual(state.data, "hello")
        XCTAssertNil(state.error)
    }

    func testErrorState() {
        let error = AppError.unknown("test error")
        let state: ViewState<String> = .error(error)
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.isSuccess)
        XCTAssertTrue(state.isError)
        XCTAssertNil(state.data)
        XCTAssertNotNil(state.error)
        XCTAssertEqual(state.error?.localizedDescription, error.localizedDescription)
    }

    func testEquality_Idle() {
        let a: ViewState<Int> = .idle
        let b: ViewState<Int> = .idle
        XCTAssertEqual(a, b)
    }

    func testEquality_Loading() {
        let a: ViewState<Int> = .loading
        let b: ViewState<Int> = .loading
        XCTAssertEqual(a, b)
    }

    func testEquality_Success() {
        let a: ViewState<Int> = .success(42)
        let b: ViewState<Int> = .success(42)
        XCTAssertEqual(a, b)
    }

    func testEquality_Success_DifferentData() {
        let a: ViewState<Int> = .success(42)
        let b: ViewState<Int> = .success(99)
        XCTAssertNotEqual(a, b)
    }

    func testEquality_Error() {
        let a: ViewState<Int> = .error(.unknown("a"))
        let b: ViewState<Int> = .error(.unknown("a"))
        XCTAssertEqual(a, b)
    }

    func testEquality_Error_DifferentMessage() {
        let a: ViewState<Int> = .error(.unknown("a"))
        let b: ViewState<Int> = .error(.unknown("b"))
        XCTAssertNotEqual(a, b)
    }

    func testEquality_DifferentStates() {
        let idle: ViewState<Int> = .idle
        let loading: ViewState<Int> = .loading
        XCTAssertNotEqual(idle, loading)
    }

    func testSuccess_WithOptionalType_SomeValue() {
        let state: ViewState<String?> = .success("hello")
        XCTAssertTrue(state.isSuccess)
        let data = state.data
        XCTAssertEqual(data ?? nil, "hello")
    }

    func testSuccess_WithArrayType() {
        let state: ViewState<[Int]> = .success([1, 2, 3])
        XCTAssertTrue(state.isSuccess)
        XCTAssertEqual(state.data, [1, 2, 3])
    }
}
