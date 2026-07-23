//
//  ConnectionRowView.swift
//  macSCP
//
//  List row for the connection list column
//

import SwiftUI

struct ConnectionRowView: View {
    let connection: Connection
    var connectionStatus: ConnectionStatus? = nil
    var isSelected: Bool = false
    @State private var isHovered = false

    private var iconColor: Color {
        switch connection.connectionType {
        case .sftp: return .blue
        case .s3:   return .orange
        }
    }

    private func statusColor(_ status: ConnectionStatus) -> Color {
        switch status {
        case .online: return .green
        case .offline: return .red
        case .checking: return .yellow
        }
    }

    // MARK: - Accessibility

    /// Composed spoken label for the entire row (A11Y-02).
    ///
    /// Joins the visible row fragments into ONE VoiceOver utterance so users
    /// no longer swipe through name / host / type / tags / time separately.
    ///
    /// Security contract (threat T-4-04): this string MUST NOT contain any
    /// credential. It draws ONLY from:
    ///   - `connection.name` (user-chosen label)
    ///   - `connection.connectionString` (`user@host` / `user@host:port` for
    ///     SFTP, `s3://bucket` for S3 — verified in Connection.swift:105-115;
    ///     contains NO password / private key / S3 secret)
    ///   - `connection.connectionType.displayName` ("SFTP" / "S3")
    ///   - optional status / favorite / last-used decoration
    ///
    /// `password`, `privateKeyPath`, `s3SecretAccessKey` are deliberately
    /// absent. The credential-leak grep gate in 04-02-PLAN.md enforces this.
    private var rowAccessibilityLabel: String {
        var parts: [String] = [
            connection.name,
            connection.connectionString,
            connection.connectionType.displayName,
        ]
        if let status = connectionStatus {
            // ConnectionStatus has no displayName; map inline (A11Y spoken form).
            let statusText: String
            switch status {
            case .online:   statusText = "Online"
            case .offline:  statusText = "Offline"
            case .checking: statusText = "Checking"
            }
            parts.append(statusText)
        }
        if connection.isFavorite {
            parts.append("Favorite")
        }
        if let lastUsed = connection.lastUsedAt {
            parts.append("Used \(lastUsed.relativeTimeString)")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: connection.iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)
                .overlay(alignment: .bottomTrailing) {
                    if let status = connectionStatus {
                        Circle()
                            .fill(statusColor(status))
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: 2)
                    }
                }
                .opacity(isSelected ? 1.0 : 0.85)

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                // Name row with trailing type badge
                HStack {
                    Text(connection.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(connection.connectionType.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                // Connection string
                Text(connection.connectionString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Tags
                if !connection.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(connection.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                        if connection.tags.count > 3 {
                            Text("+\(connection.tags.count - 3)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 1)
                }

                // Relative time (LIST-02)
                if let lastUsed = connection.lastUsedAt {
                    Text(lastUsed.relativeTimeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        // MARK: - Accessibility (A11Y-02)
        // Flatten the 5+ Text/Image fragments into ONE VoiceOver element.
        // Safe because the row body contains no interactive children — all
        // tap/drag/context-menu interactivity is applied by the CALLER in
        // ConnectionSidebarView.connectionRow(_:) (RESEARCH §Pitfall 6).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Double-tap to connect; open Actions menu for more")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.primary.opacity(0.06)
        } else {
            return Color.clear
        }
    }
}
