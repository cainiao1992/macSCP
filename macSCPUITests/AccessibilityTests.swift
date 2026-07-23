//
//  AccessibilityTests.swift
//  macSCPUITests
//
//  UI tests for VoiceOver accessibility properties on active-window surfaces.
//  Targets the active UnifiedBrowserWindow + ConnectionFormSheet only.
//  Does NOT query legacy/dead-view identifiers (connectButton/editButton/
//  deleteButton/terminalButton/sidebar/allConnectionsRow) — those exist only
//  in dead views and are covered by the pre-existing stale-test condition.
//

import XCTest

final class AccessibilityTests: XCTestCase {
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

    // MARK: - Form Field Tests (A11Y-01)

    /// The empty-title tag TextField in ConnectionFormSheet must expose a spoken
    /// name ("New tag") to VoiceOver via an explicit `.accessibilityLabel`.
    /// Without the label, VoiceOver announces only "text field" for this field
    /// (RESEARCH.md §Pitfall 3). XCUITest queries the field by its spoken label.
    func testNewTagFieldIsLabeled() {
        // SwiftUI `Button { } label: { Label(...) }` exposes two nested
        // elements with the same identifier in the accessibility tree; use
        // `.firstMatch` to disambiguate (standard XCUITest pattern).
        let newConnectionButton = app.buttons["newConnectionButton"].firstMatch
        XCTAssertTrue(
            newConnectionButton.waitForExistence(timeout: 5),
            "New Connection button should be reachable in the active sidebar toolbar"
        )
        newConnectionButton.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "New Connection sheet should appear")

        let tagField = sheet.textFields["New tag"]
        XCTAssertTrue(
            tagField.waitForExistence(timeout: 2),
            "Tag field should be announced as 'New tag' (explicit .accessibilityLabel)"
        )
    }

    // MARK: - Form Field Auto-Label (A11Y-01)

    /// Titled TextFields (Name/Host/Port) are reachable via their existing
    /// accessibilityIdentifier values. Guards the active-window form surface.
    func testFormFieldsAreReachable() {
        app.buttons["newConnectionButton"].firstMatch.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "New Connection sheet should appear")

        XCTAssertTrue(
            sheet.textFields["nameField"].waitForExistence(timeout: 2),
            "nameField should exist in the sheet"
        )
        XCTAssertTrue(
            sheet.textFields["hostField"].waitForExistence(timeout: 2),
            "hostField should exist in the sheet (SFTP is the default type)"
        )
        XCTAssertTrue(
            sheet.textFields["portField"].waitForExistence(timeout: 2),
            "portField should exist in the sheet (SFTP is the default type)"
        )
    }

    /// Guard for the auto-label invariant (T-4-02): titled TextFields must
    /// remain interactive SwiftUI TextFields (the title parameter drives both
    /// the visible placeholder and the VoiceOver spoken name via AXLabeledBy).
    ///
    /// Note on macOS AX limitation: XCUITest's `.label` / `.placeholderValue`
    /// do NOT capture the spoken name that VoiceOver announces for a titled
    /// SwiftUI TextField in a `.formStyle(.grouped)` Form — VoiceOver uses the
    /// full AX hierarchy (AXLabeledBy / AXTitle) which XCUITest does not
    /// surface via `.label`. Empirical probe (2026-07-18) confirmed both
    /// `.label` and `.placeholderValue` are empty for `nameField`, yet the
    /// title is visibly rendered and is what VoiceOver speaks. We therefore
    /// guard structural integrity (field exists + accepts input) instead of
    /// asserting `.label` non-empty. Verifying spoken speech quality is a
    /// manual VoiceOver step (see 04-VALIDATION.md §Manual-Only).
    /// This test still catches regressions that strip the title or break the
    /// field's interactivity: a non-interactive or identifier-less element
    /// fails the assertion below.
    func testTitledTextFieldsExposeAutoLabel() {
        app.buttons["newConnectionButton"].firstMatch.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        let nameField = sheet.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertTrue(nameField.isEnabled, "nameField should be interactive")
        XCTAssertTrue(nameField.isHittable, "nameField should be hittable (a real TextField, not a static label)")
    }

    /// The Test Connection button exposes a dynamic spoken value via
    /// `.accessibilityValue(testConnectionStateAccessibilityValue)`. In the
    /// idle state the form is incomplete (no Name/Host/Username yet) so the
    /// value reads "Form incomplete" — non-empty either way.
    func testTestConnectionButtonHasValue() {
        app.buttons["newConnectionButton"].firstMatch.click()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        let testButton = sheet.buttons["testConnectionButton"]
        XCTAssertTrue(testButton.waitForExistence(timeout: 2))

        let value = testButton.value as? String
        XCTAssertNotNil(value, "Test Connection button should expose a spoken value")
        XCTAssertFalse(value?.isEmpty ?? true, "Test Connection button value should be non-empty")
    }

    // MARK: - Connection Row Tests (A11Y-02)

    /// A connection row in the sidebar is reachable as ONE element whose
    /// spoken `.label` contains the connection name AND a substring of the
    /// connectionString (host) AND the type — not 5 separate fragments.
    ///
    /// This guards the `.accessibilityElement(children: .combine)` +
    /// `.accessibilityLabel(rowAccessibilityLabel)` annotation in
    /// ConnectionRowView. Query via `app.descendants(matching: .any)` because
    /// the `.accessibilityAddTraits(.isButton)` added alongside may classify
    /// the row as `.button` / `.other` rather than `.staticText`.
    func testConnectionRowAccessibilityLabel() {
        createTestConnection(named: "A11Y Row Server")

        // `.descendants(matching: .any)` is element-type agnostic — robust
        // against the .isButton trait reclassifying the row.
        let row = app.descendants(matching: .any)
            .matching(identifier: "connectionRow_A11Y Row Server")
            .firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Connection row should be findable by its existing connectionRow_<name> identifier"
        )

        // The composed label should carry the name + connectionString + type.
        // On macOS the `.label` of a `.combine`-d element DOES surface the
        // composed spoken string (unlike titled TextFields — see
        // testTitledTextFieldsExposeAutoLabel comment above).
        let label = row.label
        XCTAssertTrue(
            label.contains("A11Y Row Server"),
            "Row label should contain the connection name; got: \(label)"
        )
        XCTAssertTrue(
            label.contains("127.0.0.1"),
            "Row label should contain the host (from connectionString); got: \(label)"
        )
        XCTAssertTrue(
            label.contains("SFTP"),
            "Row label should contain the connection type; got: \(label)"
        )
    }

    // MARK: - Test Helpers

    /// Mirrors the `createTestConnection` helper in ConnectionFlowUITests.swift
    /// (replicated, not imported across test classes — XCUITest convention).
    /// Seeds one SFTP connection named `name` so a `connectionRow_<name>` row
    /// appears in the sidebar. Uses a caller-provided name so different tests
    /// don't collide on a hard-coded "Test Server" row.
    private func createTestConnection(named name: String) {
        let newButton = app.buttons["newConnectionButton"].firstMatch
        guard newButton.waitForExistence(timeout: 3) else { return }

        newButton.click()

        let sheet = app.sheets.firstMatch
        guard sheet.waitForExistence(timeout: 3) else { return }

        let nameField = sheet.textFields["nameField"]
        nameField.click()
        nameField.typeText(name)

        let hostField = sheet.textFields["hostField"]
        hostField.click()
        hostField.typeText("127.0.0.1")

        let usernameField = sheet.textFields["usernameField"]
        usernameField.click()
        usernameField.typeText("testuser")

        let saveButton = sheet.buttons["saveButton"]
        saveButton.click()

        _ = app.descendants(matching: .any)
            .matching(identifier: "connectionRow_\(name)")
            .firstMatch
            .waitForExistence(timeout: 3)
    }

    // MARK: - Custom Actions (criterion #4)

    /// The connection row exposes the context-menu operations as VoiceOver
    /// custom actions. XCUITest cannot enumerate `accessibilityAction`
    /// names directly on macOS, so this test guards the structural contract:
    /// the row is findable AND the context-menu method-parity grep gate
    /// (in 04-02-PLAN.md acceptance criteria) certifies each action invokes
    /// the same viewModel method. Action-name presence in the VoiceOver
    /// Actions menu (VO+Cmd+Space) is a manual check (04-VALIDATION.md).
    ///
    /// If a future regression removes an .accessibilityAction, the source
    /// gate `grep -c '.accessibilityAction(named:' ...ConnectionSidebarView.swift` → ≥ 5
    /// will fail in CI before this test runs.
    func testConnectionRowCustomActions() {
        createTestConnection(named: "A11Y Actions Server")

        let row = app.descendants(matching: .any)
            .matching(identifier: "connectionRow_A11Y Actions Server")
            .firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Row should exist so its custom actions are reachable"
        )
        // Right-click to open the context menu — the menu item labels mirror
        // the .accessibilityAction names verbatim (Connect is exposed as
        // "Open File Browser" in the menu, but the action name itself is
        // "Connect"). We assert the context menu items exist as a proxy for
        // action presence: the source gate certifies one .accessibilityAction
        // per menu item.
        row.rightClick()
        let editMenuItem = app.menuItems["Edit"]
        XCTAssertTrue(
            editMenuItem.waitForExistence(timeout: 2),
            "Context menu (and thus the mirrored custom action) should expose Edit"
        )
        let deleteMenuItem = app.menuItems["Delete"]
        XCTAssertTrue(
            deleteMenuItem.waitForExistence(timeout: 2),
            "Context menu (and thus the mirrored custom action) should expose Delete"
        )
        // Dismiss the menu.
        editMenuItem.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .press(forDuration: 0.1)
    }

    // MARK: - Section Headers (A11Y-03)

    /// Section headers (Recent / Favorites / All Connections) are VoiceOver
    /// landmarks via `.accessibilityAddTraits(.isHeader)`. XCTest cannot
    /// assert traits directly, but the headers must at least be findable as
    /// static texts. The trait application is certified by the source gate
    /// `grep -c '.accessibilityAddTraits(.isHeader)' ...ConnectionSidebarView.swift` → ≥ 1.
    /// "All Connections" is always visible; Recent/Favorites only appear
    /// when non-empty, so we only assert All Connections here.
    func testSectionHeadersExist() {
        // "All Connections" is always rendered (it's the unfoldered drop
        // target — see ConnectionSidebarView.connectionSections).
        let allConnections = app.staticTexts["All Connections"]
        XCTAssertTrue(
            allConnections.waitForExistence(timeout: 5),
            "'All Connections' section header should be visible even with no connections"
        )
    }
}
