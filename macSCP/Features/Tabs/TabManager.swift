//
//  TabManager.swift
//  macSCP
//
//  Observable manager for tab lifecycle (file browser + terminal tabs)
//

import Foundation

@MainActor @Observable final class TabManager {
    typealias BrowserViewModelFactory = (Connection, String) -> FileBrowserViewModel
    typealias TerminalViewModelFactory = (Connection, String) -> TerminalViewModel

    // MARK: - State

    private(set) var tabs: [TabModel] = []
    private(set) var activeTabIndex: Int?

    // MARK: - Dependencies

    private let browserViewModelFactory: BrowserViewModelFactory
    private let terminalViewModelFactory: TerminalViewModelFactory

    // MARK: - Computed

    var activeTab: TabModel? {
        guard let index = activeTabIndex, index < tabs.count else { return nil }
        return tabs[index]
    }

    var hasTabs: Bool { !tabs.isEmpty }

    // MARK: - Init

    init(
        browserViewModelFactory: @escaping BrowserViewModelFactory,
        terminalViewModelFactory: @escaping TerminalViewModelFactory
    ) {
        self.browserViewModelFactory = browserViewModelFactory
        self.terminalViewModelFactory = terminalViewModelFactory
    }

    convenience init(dependencyContainer: DependencyContainer) {
        self.init(
            browserViewModelFactory: { connection, password in
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
            },
            terminalViewModelFactory: { connection, password in
                dependencyContainer.makeTerminalViewModel(connection: connection, password: password)
            }
        )
    }

    // MARK: - Open Browser Tab

    @discardableResult
    func openTab(connection: Connection, password: String) -> TabModel {
        // Deduplication: switch to existing browser tab if connection already open
        if let existingIndex = tabs.firstIndex(where: {
            $0.connectionId == connection.id && $0.kind == .fileBrowser
        }) {
            activeTabIndex = existingIndex
            logInfo("Switched to existing browser tab for \(connection.name)", category: .ui)
            return tabs[existingIndex]
        }

        let viewModel = browserViewModelFactory(connection, password)
        // Wire terminal opening back to this manager (weak self avoids retain cycle)
        viewModel.onOpenTerminal = { [weak self] conn, pwd in
            self?.openTerminalTab(connection: conn, password: pwd)
        }
        let tab = TabModel(
            id: UUID(),
            connectionId: connection.id,
            connectionName: connection.name,
            connectionType: connection.connectionType,
            host: connection.host,
            password: password,
            kind: .fileBrowser,
            content: .fileBrowser(viewModel)
        )
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        logInfo("Opened browser tab: \(connection.name)", category: .ui)
        return tab
    }

    // MARK: - Open Terminal Tab

    @discardableResult
    func openTerminalTab(connection: Connection, password: String) -> TabModel {
        // Terminal only supported for SFTP connections
        guard connection.connectionType == .sftp else {
            logWarning("Terminal only supported for SFTP connections", category: .ui)
            // Fall back to a browser tab so the user still gets feedback
            return openTab(connection: connection, password: password)
        }

        // Deduplication: switch to existing terminal tab if connection already open
        if let existingIndex = tabs.firstIndex(where: {
            $0.connectionId == connection.id && $0.kind == .terminal
        }) {
            activeTabIndex = existingIndex
            logInfo("Switched to existing terminal tab for \(connection.name)", category: .ui)
            return tabs[existingIndex]
        }

        let viewModel = terminalViewModelFactory(connection, password)
        let tab = TabModel(
            id: UUID(),
            connectionId: connection.id,
            connectionName: connection.name,
            connectionType: connection.connectionType,
            host: connection.host,
            password: password,
            kind: .terminal,
            content: .terminal(viewModel)
        )
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        logInfo("Opened terminal tab: \(connection.name)", category: .ui)
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
        await disconnectContent(of: tab)

        // Re-find the tab by ID after async suspension — the index may have
        // changed if another closeTab call ran concurrently during the await.
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tab.id }) else {
            logWarning("closeTab: tab at index \(index) was already closed", category: .ui)
            return
        }

        tabs.remove(at: currentIndex)

        guard let activeIdx = activeTabIndex else { return }

        if currentIndex == activeIdx {
            // Closing the active tab
            if tabs.isEmpty {
                activeTabIndex = nil
            } else if currentIndex >= tabs.count {
                // Was the last tab — move to previous
                activeTabIndex = tabs.count - 1
            }
            // else: same index now points to the next tab
        } else if currentIndex < activeIdx {
            // Closing a tab before the active one — shift active left
            activeTabIndex = activeIdx - 1
        }
        // else: closing a tab after the active one — no change

        logInfo("Closed tab at index \(currentIndex)", category: .ui)
    }

    func closeAllTabs() async {
        for tab in tabs {
            await disconnectContent(of: tab)
        }
        tabs.removeAll()
        activeTabIndex = nil
        logInfo("Closed all tabs", category: .ui)
    }

    /// Disconnects the content's session based on tab kind.
    private func disconnectContent(of tab: TabModel) async {
        switch tab.content {
        case .fileBrowser(let viewModel):
            await viewModel.disconnect()
        case .terminal(let viewModel):
            await viewModel.cleanup()
        }
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
