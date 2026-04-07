//
//  EditorThemeServiceTests.swift
//  macSCPTests
//
//  Unit tests for EditorThemeService
//

import XCTest
import AppKit
@testable import macSCP

@MainActor
final class EditorThemeServiceTests: XCTestCase {

    func testLightThemeName() {
        XCTAssertEqual(EditorThemeService.lightThemeName, "solarized-light")
    }

    func testDarkThemeName() {
        XCTAssertEqual(EditorThemeService.darkThemeName, "solarized-dark")
    }

    func testThemeName_LightAppearance() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let themeName = EditorThemeService.themeName(for: lightAppearance)
        XCTAssertEqual(themeName, "solarized-light")
    }

    func testThemeName_DarkAppearance() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let themeName = EditorThemeService.themeName(for: darkAppearance)
        XCTAssertEqual(themeName, "solarized-dark")
    }

    func testIsDarkAppearance_Light() {
        let lightAppearance = NSAppearance(named: .aqua)!
        XCTAssertFalse(EditorThemeService.isDarkAppearance(lightAppearance))
    }

    func testIsDarkAppearance_Dark() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        XCTAssertTrue(EditorThemeService.isDarkAppearance(darkAppearance))
    }

    func testInsertionPointColor_Light() {
        let lightAppearance = NSAppearance(named: .aqua)!
        let color = EditorThemeService.insertionPointColor(for: lightAppearance)
        XCTAssertEqual(color, NSColor.black)
    }

    func testInsertionPointColor_Dark() {
        let darkAppearance = NSAppearance(named: .darkAqua)!
        let color = EditorThemeService.insertionPointColor(for: darkAppearance)
        XCTAssertEqual(color, NSColor.white)
    }
}
