//
//  UnifiedBrowserWindow.swift
//  macSCP
//
//  Single-window shell: sidebar placeholder + tab strip + tab content.
//

import SwiftUI

struct UnifiedBrowserWindow: View {
    let tabManager: TabManager

    var body: some View {
        NavigationSplitView {
            sidebarPlaceholder
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

    // MARK: - Sidebar Placeholder (S02 will replace with real connection list)

    private var sidebarPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Connections")
                .font(.headline)
            Text("Connection list will be integrated in the next slice.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let container = DependencyContainer.shared
    let manager = TabManager(dependencyContainer: container)
    UnifiedBrowserWindow(tabManager: manager)
}
