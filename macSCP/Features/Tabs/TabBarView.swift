//
//  TabBarView.swift
//  macSCP
//
//  Horizontal tab strip showing open connections as tabs
//

import SwiftUI

struct TabBarView: View {
    @Bindable var tabManager: TabManager
    @State private var hoveredTabId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                    tabButton(for: tab, at: index)
                }

                addButton
            }
            .padding(.horizontal, 4)
        }
        .background(.bar)
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(for tab: TabModel, at index: Int) -> some View {
        let isActive = tabManager.activeTabIndex == index
        let isHovered = hoveredTabId == tab.id

        Button {
            tabManager.switchToTab(at: index)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? .primary : .secondary)

                Text(tab.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isActive || isHovered {
                    Button {
                        Task {
                            await tabManager.closeTab(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive
                        ? Color.accentColor.opacity(0.12)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(tab.id.uuidString) {
            Text(tab.title)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let draggedUUIDString = items.first,
                  let draggedId = UUID(uuidString: draggedUUIDString),
                  let sourceIndex = tabManager.tabs.firstIndex(where: { $0.id == draggedId })
            else { return false }
            tabManager.moveTab(from: sourceIndex, to: index)
            return true
        } isTargeted: { isTargeted in
            if isTargeted {
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveredTabId = tab.id
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTabId = hovering ? tab.id : nil
            }
        }
        .contextMenu {
            Button("Close Tab") {
                Task {
                    await tabManager.closeTab(at: index)
                }
            }

            Button("Close Other Tabs") {
                Task {
                    let indicesToClose = (0..<tabManager.tabs.count)
                        .filter { $0 != index }
                        .sorted(by: >) // Close from right to left to preserve indices
                    for idx in indicesToClose {
                        await tabManager.closeTab(at: idx)
                    }
                }
            }

            Divider()

            Button("Close All Tabs") {
                Task {
                    await tabManager.closeAllTabs()
                }
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            // Placeholder — S02 will wire to open a new connection
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .help("Open New Connection")
        .padding(.leading, 4)
    }
}

// MARK: - Preview

#Preview("Tab Bar") {
    let container = DependencyContainer.shared
    let manager = TabManager(dependencyContainer: container)

    // Simulate tabs for preview — at preview time the manager is empty,
    // so this shows the empty tab bar with just the "+" button.
    VStack(spacing: 0) {
        TabBarView(tabManager: manager)
        Spacer()
    }
    .frame(width: 600, height: 100)
}
