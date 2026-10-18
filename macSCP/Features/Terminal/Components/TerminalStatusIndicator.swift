//
//  TerminalStatusIndicator.swift
//  macSCP
//
//  Animated status indicator for terminal connection state
//

import SwiftUI

/// Animated status dot for the terminal status bar.
/// Uses pulse animations for connecting/error states and steady glow for connected.
struct TerminalStatusIndicator: View {
    let state: TerminalState
    let isSessionEnded: Bool

    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return isSessionEnded ? .gray : .red
        case .error:
            return .red
        }
    }

    private var isAnimated: Bool {
        switch state {
        case .connecting, .error:
            return true
        default:
            return false
        }
    }

    var body: some View {
        StatusDot(
            color: statusColor,
            isPulsing: isAnimated,
            accessibilityLabel: accessibilityText
        )
    }

    private var accessibilityText: String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return isSessionEnded ? "Session Ended" : "Disconnected"
        case .error:
            return "Connection Error"
        }
    }
}

// MARK: - Preview

#Preview("Terminal Status Indicator") {
    HStack(spacing: 24) {
        TerminalStatusIndicator(state: .connected, isSessionEnded: false)
        TerminalStatusIndicator(state: .connecting, isSessionEnded: false)
        TerminalStatusIndicator(state: .disconnected, isSessionEnded: false)
        TerminalStatusIndicator(state: .disconnected, isSessionEnded: true)
        TerminalStatusIndicator(state: .error(.terminalConnectionLost), isSessionEnded: false)
    }
    .padding()
}
