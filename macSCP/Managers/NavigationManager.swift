//
//  NavigationManager.swift
//  macSCP
//
//  Manager for handling navigation history and path management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class NavigationManager: ObservableObject {
    @Published var isNavigating = false
    @Published var navigationHistory: [String] = []
    @Published var historyIndex: Int = -1

    private let sshManager: CitadelSFTPManager

    init(sshManager: CitadelSFTPManager) {
        self.sshManager = sshManager
    }

    var canGoBack: Bool {
        historyIndex > 0 && !isNavigating
    }

    var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1 && !isNavigating
    }

    var pathComponents: [(name: String, path: String)] {
        var result: [(String, String)] = []
        let components = sshManager.currentPath.split(separator: "/")

        if sshManager.currentPath.starts(with: "/") {
            result.append(("Root", "/"))
        }

        for (index, component) in components.enumerated() {
            let currentPath = "/" + components[0...index].joined(separator: "/")
            result.append((String(component), currentPath))
        }

        return result
    }

    func initialize() {
        if navigationHistory.isEmpty && !sshManager.currentPath.isEmpty {
            navigationHistory = [sshManager.currentPath]
            historyIndex = 0
        }
    }

    func navigateToDirectory(_ path: String, onSelection: @escaping () -> Void) {
        // Prevent overlapping navigation requests
        guard !isNavigating else { return }

        // Add to history
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory.removeLast(navigationHistory.count - historyIndex - 1)
        }
        navigationHistory.append(path)
        historyIndex = navigationHistory.count - 1

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                onSelection()
            } catch {
                print("Failed to navigate: \(error)")
                // Revert history on error
                if navigationHistory.count > 1 {
                    navigationHistory.removeLast()
                    historyIndex = navigationHistory.count - 1
                }
            }
        }
    }

    func goBack(onSelection: @escaping () -> Void) {
        guard canGoBack, !isNavigating else { return }
        historyIndex -= 1
        let path = navigationHistory[historyIndex]

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                onSelection()
            } catch {
                print("Failed to navigate: \(error)")
                historyIndex += 1 // Revert on error
            }
        }
    }

    func goForward(onSelection: @escaping () -> Void) {
        guard canGoForward, !isNavigating else { return }
        historyIndex += 1
        let path = navigationHistory[historyIndex]

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                onSelection()
            } catch {
                print("Failed to navigate: \(error)")
                historyIndex -= 1 // Revert on error
            }
        }
    }

    func refresh() {
        guard !isNavigating else { return }

        Task {
            isNavigating = true
            defer { isNavigating = false }

            try? await sshManager.listFiles(path: sshManager.currentPath)
        }
    }
}
