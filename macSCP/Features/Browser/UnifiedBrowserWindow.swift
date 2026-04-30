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
        } detail: {
            VStack(spacing: 0) {
                TabBarView(tabManager: tabManager)
                TabContentView(tabManager: tabManager)
            }
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
