//
//  BrowserFlowUITests.swift
//  macSCPUITests
//
//  UI tests for file browser flow
//

import XCTest

final class BrowserFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10), "App should launch with menu bar")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu Tests

    func testFileMenuExists() {
        let fileMenu = app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 3), "File menu should exist")
    }

    func testEditMenuExists() {
        let editMenu = app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssertTrue(editMenu.waitForExistence(timeout: 3), "Edit menu should exist")
    }

    func testViewMenuExists() {
        let viewMenu = app.menuBars.firstMatch.menuBarItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 3), "View menu should exist")
    }

    // MARK: - Keyboard Shortcut Tests

    func testCommandNOpensNewConnection() {
        app.typeKey("n", modifierFlags: .command)

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "New connection sheet should appear after Cmd+N")

        let nameField = sheet.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name field should exist in sheet")
    }

    func testCommandRDoesNotCrash() {
        XCTAssertTrue(app.menuBars.firstMatch.waitForExistence(timeout: 3))

        app.typeKey("r", modifierFlags: .command)

        XCTAssertTrue(app.menuBars.firstMatch.waitForExistence(timeout: 3), "App should still be running after Cmd+R")
    }

    // MARK: - Window Management Tests

    func testMultipleWindowsCanBeOpened() {
        let newButton = app.buttons["newConnectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))

        newButton.click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        XCTAssertTrue(sheet.exists, "Sheet should be visible")

        let cancelButton = sheet.buttons["cancelButton"]
        if cancelButton.exists {
            cancelButton.click()
        }
    }

    // MARK: - Toolbar Tests

    func testToolbarButtonsAccessible() {
        XCTAssertTrue(app.menuBars.firstMatch.waitForExistence(timeout: 3))

        let newButton = app.buttons["newConnectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 3), "New connection button should be accessible")
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(macOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
