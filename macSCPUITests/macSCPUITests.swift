//
//  macSCPUITests.swift
//  macSCPUITests
//
//  Created by Nevil Macwan on 30/01/26.
//

import XCTest

final class macSCPUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunchesSuccessfully() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10), "App should launch with menu bar")
    }
}
