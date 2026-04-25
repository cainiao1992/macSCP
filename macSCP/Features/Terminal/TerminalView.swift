//
//  TerminalView.swift
//  macSCP
//
//  Terminal view with SwiftTerm integration
//

import SwiftUI
import AppKit
import SwiftTerm

// MARK: - Terminal View

struct TerminalContentView: View {
    @Bindable var viewModel: TerminalViewModel

    @State private var showConnectionLostBanner = false
    @State private var showSessionEndedBanner = false

    var body: some View {
        VStack(spacing: 0) {
            // Terminal content
            terminalContent

            Divider()

            // Status bar
            statusBar
        }
        .frame(minWidth: WindowSize.minTerminal.width, minHeight: WindowSize.minTerminal.height)
        .navigationTitle(viewModel.connectionName)
        .navigationSubtitle(navigationSubtitleText)
        .toolbar(id: "terminalToolbar") {
            ToolbarItem(id: "disconnect", placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.disconnect()
                    }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .disabled(!viewModel.isConnected)
                .help("Disconnect")
                .accessibilityLabel("Disconnect")
                .accessibilityHint("Disconnect from the remote server")
            }

            ToolbarItem(id: "reconnect", placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.reconnect()
                    }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state == .connecting)
                .help("Reconnect")
                .accessibilityLabel("Reconnect")
                .accessibilityHint("Reconnect to the remote server")
            }

            ToolbarItem(id: "decreaseFontSize", placement: .primaryAction) {
                Button {
                    viewModel.decreaseFontSize()
                } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
                .help("Decrease Font Size")
                .accessibilityLabel("Decrease Font Size")
            }

            ToolbarItem(id: "increaseFontSize", placement: .primaryAction) {
                Button {
                    viewModel.increaseFontSize()
                } label: {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                .help("Increase Font Size")
                .accessibilityLabel("Increase Font Size")
            }
        }
        .task {
            await viewModel.connect()
        }
        .onDisappear {
            Task {
                await viewModel.cleanup()
            }
        }
        .onChange(of: viewModel.state) { oldState, newState in
            // Show banner overlay when connection is lost while terminal was connected
            if case .connected = oldState, case .error = newState {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showConnectionLostBanner = true
                    showSessionEndedBanner = false
                }
            } else if case .connected = oldState, case .disconnected = newState {
                // Graceful session end (e.g. CTRL-D / exit)
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showSessionEndedBanner = true
                    showConnectionLostBanner = false
                }
            } else if case .connected = newState {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showConnectionLostBanner = false
                    showSessionEndedBanner = false
                }
            } else if case .connecting = newState {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showConnectionLostBanner = false
                    showSessionEndedBanner = false
                }
            }
        }
        .errorAlert($viewModel.error)
        .alert("Host Key Changed", isPresented: $viewModel.isShowingHostKeyMismatchAlert) {
            Button("Disconnect", role: .cancel) {
                viewModel.disconnectAfterHostKeyMismatch()
            }
            Button("Replace Key & Connect", role: .destructive) {
                Task {
                    await viewModel.replaceHostKeyAndReconnect()
                }
            }
        } message: {
            Text("The server's host key has changed. This may indicate the server has been reconfigured, or it could be a security concern.\n\nWould you like to replace the stored key and connect, or disconnect?")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                TerminalStatusIndicator(
                    state: viewModel.state,
                    isSessionEnded: showSessionEndedBanner
                )

                Text(statusBarText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(statusBarText)

            // Connection duration
            if viewModel.isConnected && !viewModel.connectionDuration.isEmpty {
                Text(viewModel.connectionDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Terminal dimensions
            if viewModel.isConnected || showConnectionLostBanner || showSessionEndedBanner {
                Text(viewModel.terminalSizeText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Terminal size: \(viewModel.terminalSizeText)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var terminalContent: some View {
        switch viewModel.state {
        case .disconnected:
            if showSessionEndedBanner {
                // Session ended gracefully — show non-blocking top banner
                ZStack(alignment: .top) {
                    SwiftTermView(viewModel: viewModel)

                    TerminalBannerView(
                        style: .info,
                        title: "Session Ended",
                        description: "The remote shell has exited.",
                        actionLabel: "Reconnect",
                        action: {
                            Task {
                                showSessionEndedBanner = false
                                await viewModel.reconnect()
                            }
                        },
                        dismiss: {
                            showSessionEndedBanner = false
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                ContentUnavailableView {
                    Label("Disconnected", systemImage: "terminal")
                } description: {
                    Text("The terminal session is not connected.")
                } actions: {
                    Button {
                        Task {
                            await viewModel.reconnect()
                        }
                    } label: {
                        Text("Connect")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }

        case .connecting:
            if viewModel.isReconnecting {
                // Reconnecting — preserve terminal content with inline loading overlay
                ZStack(alignment: .top) {
                    SwiftTermView(viewModel: viewModel)

                    InlineLoadingView(message: {
                        var text = "Reconnecting..."
                        if !viewModel.connectionAttemptDuration.isEmpty {
                            text += " (\(viewModel.connectionAttemptDuration))"
                        }
                        return text
                    }())
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)

                    HStack(spacing: 4) {
                        Text("Connecting...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if !viewModel.connectionAttemptDuration.isEmpty {
                            Text("(\(viewModel.connectionAttemptDuration))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Button("Cancel") {
                        Task {
                            await viewModel.cancelConnection()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .connected:
            SwiftTermView(viewModel: viewModel)
                .accessibilityLabel("Terminal output")

        case .error:
            if showConnectionLostBanner {
                // Connection lost — show non-blocking top banner
                ZStack(alignment: .top) {
                    SwiftTermView(viewModel: viewModel)

                    TerminalBannerView(
                        style: .error,
                        title: "Connection Lost",
                        description: {
                            if !viewModel.autoReconnectCountdown.isEmpty {
                                return "Reconnecting in \(viewModel.autoReconnectCountdown)... (attempt \(viewModel.autoReconnectAttempt)/\(TerminalViewModel.maxAutoReconnectAttempts))"
                            } else if case .error(let error) = viewModel.state {
                                return error.localizedDescription
                            }
                            return nil
                        }(),
                        actionLabel: "Reconnect",
                        action: {
                            Task {
                                showConnectionLostBanner = false
                                await viewModel.reconnect()
                            }
                        },
                        dismiss: {
                            showConnectionLostBanner = false
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                // Initial connection error — show categorized error view
                if case .error(let error) = viewModel.state {
                    TerminalConnectionErrorView(error: error) {
                        Task {
                            await viewModel.reconnect()
                        }
                    }
                }
            }
        }
    }

    /// Text shown in the window's navigation subtitle
    private var navigationSubtitleText: String {
        switch viewModel.state {
        case .connected:
            return viewModel.connectionString
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return showSessionEndedBanner ? "Session Ended" : "Disconnected"
        case .error:
            return "Connection Error"
        }
    }

    /// Text shown in the bottom status bar
    private var statusBarText: String {
        switch viewModel.state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return showSessionEndedBanner ? "Session Ended" : "Disconnected"
        case .error:
            return "Connection Lost"
        }
    }
}

// MARK: - SwiftTerm View (Minimal Wrapper)

struct SwiftTermView: NSViewRepresentable {
    @Bindable var viewModel: TerminalViewModel

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.font = NSFont.monospacedSystemFont(
            ofSize: CGFloat(viewModel.terminalFontSize),
            weight: .regular
        )
        context.coordinator.terminal = terminal

        // Set up output callback
        viewModel.onOutput = { [weak coordinator = context.coordinator] data in
            DispatchQueue.main.async {
                coordinator?.terminal?.feed(byteArray: ArraySlice([UInt8](data)))
            }
        }

        // Focus after appearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            terminal.window?.makeFirstResponder(terminal)
        }

        return terminal
    }

    func updateNSView(_ terminal: TerminalView, context: Context) {
        context.coordinator.terminal = terminal

        // Update font size when it changes
        let newFont = NSFont.monospacedSystemFont(
            ofSize: CGFloat(viewModel.terminalFontSize),
            weight: .regular
        )
        if terminal.font != newFont {
            terminal.font = newFont
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, TerminalViewDelegate {
        var viewModel: TerminalViewModel
        weak var terminal: TerminalView?

        init(viewModel: TerminalViewModel) {
            self.viewModel = viewModel
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            guard newCols > 0, newRows > 0 else { return }
            viewModel.resize(columns: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            viewModel.sendInput(Data(data))
        }

        func scrolled(source: TerminalView, position: Double) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(string, forType: .string)
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

// MARK: - Preview

#Preview {
    TerminalContentView(
        viewModel: TerminalViewModel(
            connectionName: "Test Server",
            session: SystemTerminalSession(),
            connectionData: TerminalWindowData(
                connectionId: UUID(),
                connectionName: "Test",
                host: "localhost",
                port: 2222,
                username: "testuser",
                password: "testpass",
                authMethod: .password,
                privateKeyPath: nil
            )
        )
    )
}
