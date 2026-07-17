//
//  TerminalConnectionErrorView.swift
//  macSCP
//
//  Category-specific error view for terminal connection failures
//

import SwiftUI

/// Displays a categorized terminal connection error with appropriate
/// icon, message, recovery suggestion, and action buttons.
struct TerminalConnectionErrorView: View {
    let error: AppError
    let retryAction: () -> Void

    private var category: ErrorCategory {
        switch error {
        case .authenticationFailed:
            return .authentication
        case .connectionTimeout:
            return .timeout
        case .hostUnreachable, .connectionLost:
            return .network
        case .hostKeyMismatch:
            return .hostKey
        default:
            return .generic
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Category-specific icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: category.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: category.icon)
                    .font(.system(size: 26, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(category.iconColor)
            }

            VStack(spacing: 8) {
                Text(category.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(error.localizedDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            Button {
                retryAction()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error Category

extension TerminalConnectionErrorView {
    enum ErrorCategory {
        case authentication
        case network
        case timeout
        case hostKey
        case generic

        var icon: String {
            switch self {
            case .authentication: return "lock.fill"
            case .network: return "wifi.exclamationmark"
            case .timeout: return "clock.badge.exclamationmark"
            case .hostKey: return "key.fill"
            case .generic: return "exclamationmark.triangle.fill"
            }
        }

        var title: String {
            switch self {
            case .authentication: return "Authentication Failed"
            case .network: return "Network Error"
            case .timeout: return "Connection Timed Out"
            case .hostKey: return "Host Key Mismatch"
            case .generic: return "Connection Failed"
            }
        }

        var iconColor: Color {
            switch self {
            case .authentication: return .orange
            case .network: return .red
            case .timeout: return .orange
            case .hostKey: return .yellow
            case .generic: return .red
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .authentication:
                return [.orange.opacity(0.15), .yellow.opacity(0.1)]
            case .network:
                return [.red.opacity(0.15), .orange.opacity(0.1)]
            case .timeout:
                return [.orange.opacity(0.15), .orange.opacity(0.08)]
            case .hostKey:
                return [.yellow.opacity(0.15), .orange.opacity(0.1)]
            case .generic:
                return [.red.opacity(0.15), .orange.opacity(0.1)]
            }
        }
    }
}

// MARK: - Preview

#Preview("Terminal Connection Errors") {
    VStack(spacing: 24) {
        TerminalConnectionErrorView(
            error: .authenticationFailed,
            retryAction: {}
        )
        .frame(width: 350, height: 280)

        TerminalConnectionErrorView(
            error: .connectionTimeout,
            retryAction: {}
        )
        .frame(width: 350, height: 280)
    }
}
