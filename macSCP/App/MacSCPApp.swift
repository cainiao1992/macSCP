//
//  MacSCPApp.swift
//  macSCP
//
//  Main application entry point
//

import SwiftUI
import SwiftData
import Sparkle

@main
struct MacSCPApp: App {
    @StateObject private var container: DependencyContainer
    @State private var connectionListViewModel: ConnectionListViewModel

    private let updaterController: SPUStandardUpdaterController
    @StateObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel

    init() {
        let container = DependencyContainer.shared
        self._container = StateObject(wrappedValue: container)
        self._connectionListViewModel = State(initialValue: container.makeConnectionListViewModel())

        AnalyticsService.initialize()
        container.appLockManager.lockIfNeeded()

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        self._checkForUpdatesViewModel = StateObject(
            wrappedValue: CheckForUpdatesViewModel(updater: controller.updater)
        )
    }

    var body: some Scene {
        // Unified Browser Window (tabbed file browser + connection sidebar)
        WindowGroup("macSCP") {
            UnifiedBrowserWindow(
                tabManager: container.tabManager,
                connectionListViewModel: connectionListViewModel
            )
            .appLockOverlay()
                .environment(\.appLockManager, container.appLockManager)
                .environment(\.windowManager, container.windowManager)
                .environment(\.biometricService, BiometricAuthService.shared)
        }
        .modelContainer(container.modelContainer)
        .defaultSize(WindowSize.fileBrowser)
        .commands {
            appCommands
        }

        // File Editor Window
        WindowGroup(id: WindowID.fileEditor, for: String.self) { $windowId in
            if let windowId = windowId {
                FileEditorWindow(windowId: windowId)
                    .appLockOverlay()
                    .environment(\.appLockManager, container.appLockManager)
                    .environment(\.windowManager, container.windowManager)
                    .environment(\.makeFileEditorDependencies, { data in
                        try await container.makeFileEditorDependencies(for: data)
                    })
            }
        }
        .modelContainer(container.modelContainer)
        .defaultSize(WindowSize.fileEditor)

        // File Info Window
        WindowGroup(id: WindowID.fileInfo, for: String.self) { $windowId in
            if let windowId = windowId {
                FileInfoWindow(windowId: windowId)
                    .appLockOverlay()
                    .environment(\.appLockManager, container.appLockManager)
                    .environment(\.windowManager, container.windowManager)
            }
        }
        .modelContainer(container.modelContainer)
        .defaultSize(WindowSize.fileInfo)
        .windowResizability(.contentSize)

        // Terminal Window
        WindowGroup(id: WindowID.terminal, for: String.self) { $windowId in
            if let windowId = windowId {
                TerminalWindow(windowId: windowId)
                    .appLockOverlay()
                    .environment(\.appLockManager, container.appLockManager)
                    .environment(\.windowManager, container.windowManager)
                    .environment(\.makeTerminalSession, { container.makeTerminalSession(connectionData: $0) })
                    .environment(\.makeTerminalViewModel, { container.makeTerminalViewModel(connectionName: $0, session: $1, connectionData: $2) })
            }
        }
        .modelContainer(container.modelContainer)
        .defaultSize(WindowSize.terminal)

        // Settings Window (Cmd+,)
        Settings {
            SettingsView()
                .appLockOverlay()
                .environment(\.appLockManager, container.appLockManager)
                .environment(\.biometricService, BiometricAuthService.shared)
        }
    }

    // MARK: - Commands
    @CommandsBuilder
    private var appCommands: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesView(viewModel: checkForUpdatesViewModel)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Connection") {
                connectionListViewModel.isShowingNewConnectionSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Tab") {
                connectionListViewModel.isShowingNewConnectionSheet = true
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("New Folder") {
                connectionListViewModel.isShowingNewFolderSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button("Refresh") {
                // Handled by active window
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Close Tab") {
                Task {
                    await container.tabManager.closeTab(at: container.tabManager.activeTabIndex ?? 0)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!container.tabManager.hasTabs)

            Divider()

            Button("Next Tab") {
                container.tabManager.switchToNextTab()
            }
            .keyboardShortcut(.tab, modifiers: .control)

            Button("Previous Tab") {
                container.tabManager.switchToPreviousTab()
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("Report a Bug…") {
                if let url = URL(string: "https://github.com/cainiao1992/macSCP/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
