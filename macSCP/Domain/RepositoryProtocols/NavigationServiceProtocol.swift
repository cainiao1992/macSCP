//
//  NavigationServiceProtocol.swift
//  macSCP
//
//  Protocol for browser navigation history — enables constructor injection
//  of the concrete NavigationService (Phase 9 DI pattern).
//

import Foundation

@MainActor
protocol NavigationServiceProtocol: AnyObject {
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var currentPath: String? { get }

    func navigate(to path: String)
    func goBack() -> String?
    func goForward() -> String?
    func reset()
    func reset(to path: String)
}
