//
//  ConnectionFlowUITests.swift
//  macSCPUITests
//
//  UI tests for connection management flow
//

import XCTest

final class ConnectionFlowUITests: XCTestCase {
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

    // MARK: - App Launch Tests

    func testAppLaunchesWithSidebar() {
        let sidebar = app.outlines["sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), "Sidebar should be visible")
    }

    func testAppLaunchesWithNewConnectionButton() {
        let newButton = app.buttons["newConnectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5), "New connection button should be visible")
    }

    func testAllConnectionsRowExists() {
        let allConnectionsRow = app.staticTexts["allConnectionsRow"]
        XCTAssertTrue(allConnectionsRow.waitForExistence(timeout: 5), "All Connections row should exist")
    }

    // MARK: - Connection Creation Flow

    func testCreateNewConnection() {
        let newButton = app.buttons["newConnectionButton"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))

        newButton.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "New connection sheet should appear")

        let nameField = sheet.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name field should exist")

        let hostField = sheet.textFields["hostField"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 2), "Host field should exist")

        let usernameField = sheet.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 2), "Username field should exist")

        let portField = sheet.textFields["portField"]
        XCTAssertTrue(portField.waitForExistence(timeout: 2), "Port field should exist")

        nameField.tap()
        nameField.typeText("Test Server")

        hostField.tap()
        hostField.typeText("127.0.0.1")

        usernameField.tap()
        usernameField.typeText("testuser")

        portField.tap()
        portField.typeText("22")

        let saveButton = sheet.buttons["saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2), "Sheet should dismiss")

        let connectionRow = app.staticTexts["Test Server"]
        XCTAssertTrue(connectionRow.waitForExistence(timeout: 3), "New connection should appear in list")
    }

    func testCancelNewConnection() {
        app.buttons["newConnectionButton"].click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        let cancelButton = sheet.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        cancelButton.click()

        XCTAssertFalse(sheet.waitForExistence(timeout: 2), "Sheet should dismiss without saving")
    }

    // MARK: - Connection Selection Flow

    func testSelectConnectionShowsDetails() {
        createTestConnection()

        let connectionRow = app.staticTexts["Test Server"]
        XCTAssertTrue(connectionRow.waitForExistence(timeout: 5))
        connectionRow.click()

        let connectButton = app.buttons["connectButton"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 3), "Connect button should appear in detail view")
    }

    // MARK: - Connection Actions

    func testEditConnectionButtonExists() {
        createTestConnection()

        let connectionRow = app.staticTexts["Test Server"]
        XCTAssertTrue(connectionRow.waitForExistence(timeout: 5))
        connectionRow.click()

        let editButton = app.buttons["editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit button should appear")
    }

    func testDeleteConnectionButtonExists() {
        createTestConnection()

        let connectionRow = app.staticTexts["Test Server"]
        XCTAssertTrue(connectionRow.waitForExistence(timeout: 5))
        connectionRow.click()

        let deleteButton = app.buttons["deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear")
    }

    // MARK: - Search Flow

    func testSearchFiltersConnections() {
        createTestConnection()

        let searchField = app.searchFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should be visible")

        searchField.click()
        searchField.typeText("Test")

        let filteredRow = app.staticTexts["Test Server"]
        XCTAssertTrue(filteredRow.waitForExistence(timeout: 3), "Matching connection should appear")

        searchField.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])

        let allRow = app.staticTexts["allConnectionsRow"]
        XCTAssertTrue(allRow.waitForExistence(timeout: 3), "All connections should be visible after clearing search")
    }

    func testTerminalButtonExists() {
        createTestConnection()

        let connectionRow = app.staticTexts["Test Server"]
        XCTAssertTrue(connectionRow.waitForExistence(timeout: 5))
        connectionRow.click()

        let terminalButton = app.buttons["terminalButton"]
        XCTAssertTrue(terminalButton.waitForExistence(timeout: 3), "Terminal button should appear for SFTP connection")
    }

    // MARK: - Helpers

    private func createTestConnection() {
        let newButton = app.buttons["newConnectionButton"]
        guard newButton.waitForExistence(timeout: 3) else { return }

        newButton.click()

        let sheet = app.sheets.firstMatch
        guard sheet.waitForExistence(timeout: 3) else { return }

        let nameField = sheet.textFields["nameField"]
        nameField.click()
        nameField.typeText("Test Server")

        let hostField = sheet.textFields["hostField"]
        hostField.click()
        hostField.typeText("127.0.0.1")

        let usernameField = sheet.textFields["usernameField"]
        usernameField.click()
        usernameField.typeText("testuser")

        let saveButton = sheet.buttons["saveButton"]
        saveButton.click()

        _ = app.staticTexts["Test Server"].waitForExistence(timeout: 3)
    }
}
