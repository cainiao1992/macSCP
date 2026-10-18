//
//  TabContentView.swift
//  macSCP
//
//  Content area that renders the active tab's file browser, or an empty state
//

import SwiftUI

struct TabContentView: View {
    @Bindable var tabManager: TabManager

    var body: some View {
        if tabManager.hasTabs, let tab = tabManager.activeTab {
            tabContent(for: tab)
                .id(tab.id) // Force SwiftUI to recreate per tab — prevents view reuse across tab switches
        } else {
            emptyState
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: TabModel) -> some View {
        switch tab.content {
        case .fileBrowser(let viewModel):
            FileBrowserView(viewModel: viewModel)
        case .terminal(let viewModel):
            TerminalContentView(viewModel: viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "rectangle.split.2x1",
            title: "No Connection Open",
            message: "Open a connection from the sidebar to start browsing."
        )
    }
}

// MARK: - Preview

#Preview("No Tabs") {
    let container = DependencyContainer.shared
    let manager = TabManager(dependencyContainer: container)
    TabContentView(tabManager: manager)
        .frame(width: 800, height: 600)
}
