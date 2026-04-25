//
//  TerminalBannerView.swift
//  macSCP
//
//  Non-blocking top banner for terminal connection status notifications
//

import SwiftUI

/// A non-blocking top banner that slides in from the top of the terminal.
/// Unlike the previous centered card overlay, this banner preserves terminal
/// interactivity (scroll, select, copy) beneath it.
struct TerminalBannerView: View {
    let style: BannerStyle
    let title: String
    let description: String?
    let actionLabel: String
    let action: () -> Void
    let dismiss: () -> Void

    enum BannerStyle {
        case error
        case info

        var icon: String {
            switch self {
            case .error: return "wifi.slash"
            case .info: return "terminal"
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .error: return [.red.opacity(0.9), .red.opacity(0.75)]
            case .info: return [.secondary.opacity(0.5), .secondary.opacity(0.35)]
            }
        }

        var foregroundColor: Color {
            switch self {
            case .error: return .white
            case .info: return .primary
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(style.foregroundColor.opacity(0.9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.foregroundColor)

                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(style.foregroundColor.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                action()
            } label: {
                Text(actionLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(style.foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(style.foregroundColor.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(style.foregroundColor.opacity(0.7))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: style.gradientColors,
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Terminal Banners") {
    VStack(spacing: 16) {
        TerminalBannerView(
            style: .error,
            title: "Connection Lost",
            description: "The terminal connection was lost.",
            actionLabel: "Reconnect",
            action: {},
            dismiss: {}
        )

        TerminalBannerView(
            style: .info,
            title: "Session Ended",
            description: "The remote shell has exited.",
            actionLabel: "Reconnect",
            action: {},
            dismiss: {}
        )
    }
    .padding()
    .frame(width: 500)
}
