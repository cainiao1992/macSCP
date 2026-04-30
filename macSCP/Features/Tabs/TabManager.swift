//
//  TabManager.swift
//  macSCP
//
//  Observable manager for browser tab lifecycle
//

import Foundation

@MainActor @Observable final class TabManager {
    typealias ViewModelFactory = (Connection, String) -> FileBrowserViewModel

    // MARK: - State

    private(set) var tabs: [TabModel] = []
    private(set) var activeTabIndex: Int?

    // MARK: - Dependencies

    private let viewModelFactory: ViewModelFactory

    // MARK: - Computed

    var activeTab: TabModel? {
        guard let index = activeTabIndex, index < tabs.count else { return nil }
        return tabs[index]
    }

    var hasTabs: Bool { !tabs.isEmpty }

    // MARK: - Init

    init(viewModelFactory: @escaping ViewModelFactory) {
        self.viewModelFactory = viewModelFactory
    }

    convenience init(dependencyContainer: DependencyContainer) {
        self.init { connection, password in
            if connection.connectionType == .s3 {
                let session = dependencyContainer.makeS3Session()
                return dependencyContainer.makeS3FileBrowserViewModel(
                    connection: connection, s3Session: session, secretAccessKey: password
                )
            } else {
                let session = dependencyContainer.makeSFTPSession()
                return dependencyContainer.makeFileBrowserViewModel(
                    connection: connection, sftpSession: session, password: password
                )
            }
        }
    }

    convenience init() {
        self.init(dependencyContainer: .shared)
    }

    // MARK: - Open

    @discardableResult
    func openTab(connection: Connection, password: String) -> TabModel {
        // Deduplication: switch to existing tab if connection already open
        if let existingIndex = tabs.firstIndex(where: { $0.connectionId == connection.id }) {
            activeTabIndex = existingIndex
            logInfo("Switched to existing tab for \(connection.name)", category: .ui)
            return tabs[existingIndex]
        }

        let viewModel = viewModelFactory(connection, password)
        let tab = TabModel(
            id: UUID(),
            connectionId: connection.id,
            connectionName: connection.name,
            connectionType: connection.connectionType,
            host: connection.host,
            password: password,
            viewModel: viewModel
        )
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        logInfo("Opened tab: \(connection.name)", category: .ui)
        return tab
    }

    // MARK: - Reorder

    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < tabs.count,
              destinationIndex >= 0, destinationIndex < tabs.count else {
            logError("moveTab: source \(sourceIndex) or destination \(destinationIndex) out of bounds", category: .ui)
            return
        }
        guard sourceIndex != destinationIndex else { return }

        let tab = tabs.remove(at: sourceIndex)
        tabs.insert(tab, at: destinationIndex)

        // Adjust activeTabIndex to follow the active tab
        if let currentActive = activeTabIndex {
            if currentActive == sourceIndex {
                // The moved tab was active — update to new position
                activeTabIndex = destinationIndex
            } else if sourceIndex < currentActive && destinationIndex >= currentActive {
                // Active tab was between source and destination (source was before active,
                // destination is at or after active) — active shifted left by 1
                activeTabIndex = currentActive - 1
            } else if sourceIndex > currentActive && destinationIndex <= currentActive {
                // Active tab was between source and destination (source was after active,
                // destination is at or before active) — active shifted right by 1
                activeTabIndex = currentActive + 1
            }
            // else: active tab is outside the moved range — no change
        }

        logInfo("Moved tab from \(sourceIndex) to \(destinationIndex)", category: .ui)
    }

    // MARK: - Close

    func closeTab(at index: Int) async {
        guard index >= 0, index < tabs.count else {
            logError("closeTab: index \(index) out of bounds", category: .ui)
            return
        }

        let tab = tabs[index]
        await tab.viewModel.disconnect()
        tabs.remove(at: index)

        guard let currentIndex = activeTabIndex else { return }

        if index == currentIndex {
            // Closing the active tab
            if tabs.isEmpty {
                activeTabIndex = nil
            } else if index >= tabs.count {
                // Was the last tab — move to previous
                activeTabIndex = tabs.count - 1
            }
            // else: same index now points to the next tab
        } else if index < currentIndex {
            // Closing a tab before the active one — shift active left
            activeTabIndex = currentIndex - 1
        }
        // else: closing a tab after the active one — no change

        logInfo("Closed tab at index \(index)", category: .ui)
    }

    func closeAllTabs() async {
        for tab in tabs {
            await tab.viewModel.disconnect()
        }
        tabs.removeAll()
        activeTabIndex = nil
        logInfo("Closed all tabs", category: .ui)
    }

    // MARK: - Switch

    func switchToTab(at index: Int) {
        guard index >= 0, index < tabs.count else {
            logError("switchToTab: index \(index) out of bounds", category: .ui)
            return
        }
        activeTabIndex = index
        logInfo("Switched to tab at index \(index)", category: .ui)
    }

    @discardableResult
    func switchToTab(for connectionId: UUID) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.connectionId == connectionId }) else {
            logError("switchToTab: no tab found for connection \(connectionId)", category: .ui)
            return false
        }
        activeTabIndex = index
        logInfo("Switched to tab for connection \(connectionId)", category: .ui)
        return true
    }

    // MARK: - Keyboard Navigation

    func switchToNextTab() {
        guard let currentIndex = activeTabIndex, tabs.count > 1 else { return }
        activeTabIndex = (currentIndex + 1) % tabs.count
        logInfo("Switched to next tab (index \(activeTabIndex!))", category: .ui)
    }

    func switchToPreviousTab() {
        guard let currentIndex = activeTabIndex, tabs.count > 1 else { return }
        activeTabIndex = (currentIndex - 1 + tabs.count) % tabs.count
        logInfo("Switched to previous tab (index \(activeTabIndex!))", category: .ui)
    }
}
