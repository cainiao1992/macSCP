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

    @State private var isPulsing = false

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
        Circle()
            .fill(
                RadialGradient(
                    colors: [statusColor.opacity(0.6), statusColor],
                    center: .center,
                    startRadius: 0,
                    endRadius: 3.5
                )
            )
            .frame(width: 7, height: 7)
            .shadow(color: statusColor.opacity(0.4), radius: isAnimated ? 3 : 1.5)
            .scaleEffect(isAnimated && isPulsing ? 1.2 : 1.0)
            .opacity(isAnimated && !isPulsing ? 0.5 : 1.0)
            .animation(
                isAnimated
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                if isAnimated {
                    isPulsing = true
                }
            }
            .onChange(of: state) { _, newState in
                switch newState {
                case .connecting, .error:
                    isPulsing = true
                default:
                    isPulsing = false
                }
            }
            .accessibilityLabel(accessibilityText)
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
