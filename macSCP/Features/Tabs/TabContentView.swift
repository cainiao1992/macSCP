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
            FileBrowserView(viewModel: tab.viewModel)
                .id(tab.id) // Force SwiftUI to recreate per tab — prevents view reuse across tab switches
        } else {
            emptyState
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.15), .cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 32, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("No Connection Open")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Open a connection from the sidebar to start browsing.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("No Tabs") {
    let container = DependencyContainer.shared
    let manager = TabManager(dependencyContainer: container)
    TabContentView(tabManager: manager)
        .frame(width: 800, height: 600)
}
