//
//  EditorThemeService.swift
//  macSCP
//
//  Maps macOS appearance to Highlightr theme names
//

import AppKit

enum EditorThemeService {
    static let lightThemeName = "solarized-light"
    static let darkThemeName = "solarized-dark"

    // MARK: - Theme Selection

    static func themeName(for appearance: NSAppearance) -> String {
        isDarkAppearance(appearance) ? darkThemeName : lightThemeName
    }

    static func insertionPointColor(for appearance: NSAppearance) -> NSColor {
        isDarkAppearance(appearance) ? .white : .black
    }

    static func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
