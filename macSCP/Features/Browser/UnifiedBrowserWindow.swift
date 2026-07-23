//
//  UnifiedBrowserWindow.swift
//  macSCP
//
//  Single-window shell: connection sidebar + tab strip + tab content.
//

import SwiftUI

struct UnifiedBrowserWindow: View {
    let tabManager: TabManager
    @Bindable var connectionListViewModel: ConnectionListViewModel

    var body: some View {
        NavigationSplitView {
            ConnectionSidebarView(viewModel: connectionListViewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 480)
                // MARK: Accessibility (A11Y-03) — name the sidebar region.
                // .contain (not .combine) keeps children navigable: users
                // VO+Shift+↓ INTO the region to reach sidebar contents. The
                // .accessibilityLabel makes VoiceOver announce
                // "Connections, sidebar" instead of an unnamed region.
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Connections")
        } detail: {
            VStack(spacing: 0) {
                TabBarView(tabManager: tabManager)
                TabContentView(tabManager: tabManager)
            }
            // MARK: Accessibility (A11Y-03) — name the detail region.
            // Same .contain + label pattern as the sidebar; VoiceOver
            // announces "File browser, content" and users move between the
            // two regions with VO+Shift+↓/↑.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("File browser")
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: WindowSize.minFileBrowser.width,
            minHeight: WindowSize.minFileBrowser.height
        )
    }
}

// MARK: - Preview

#Preview {
    let container = DependencyContainer.shared
    let manager = TabManager(dependencyContainer: container)
    let vm = container.makeConnectionListViewModel()
    UnifiedBrowserWindow(tabManager: manager, connectionListViewModel: vm)
}
