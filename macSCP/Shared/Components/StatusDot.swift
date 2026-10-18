//
//  StatusDot.swift
//  macSCP
//
//  Shared connection status dot used by the browser and terminal status bars.
//

import SwiftUI

/// Core status dot: steady glow by default, pulse animation for transient states.
struct StatusDot: View {
    let color: Color
    var isPulsing: Bool = false
    var accessibilityLabel: String = ""

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.4), radius: isPulsing && isAnimating ? 3 : 1.5)
            .scaleEffect(isPulsing && isAnimating ? 1.2 : 1.0)
            .opacity(isPulsing && !isAnimating ? 0.5 : 1.0)
            .animation(
                isPulsing
                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onAppear {
                if isPulsing { isAnimating = true }
            }
            .onChange(of: isPulsing) { _, pulsing in
                isAnimating = pulsing
            }
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Boolean convenience for the common connected / disconnected status bar dot.
struct ConnectionStatusDot: View {
    let isConnected: Bool

    var body: some View {
        StatusDot(
            color: isConnected ? .green : .red,
            accessibilityLabel: isConnected ? "Connected" : "Disconnected"
        )
    }
}

// MARK: - Preview

#Preview("Status Dots") {
    HStack(spacing: 24) {
        ConnectionStatusDot(isConnected: true)
        ConnectionStatusDot(isConnected: false)
        StatusDot(color: .orange, isPulsing: true, accessibilityLabel: "Connecting")
    }
    .padding()
}
