//
//  ConnectionRowView.swift
//  macSCP
//
//  List row for the connection list column
//

import SwiftUI

struct ConnectionRowView: View {
    let connection: Connection

    private var iconColor: Color {
        switch connection.connectionType {
        case .sftp: return .blue
        case .s3:   return .orange
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: connection.iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)

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

            }
        }
        .padding(.vertical, 4)
    }
}
