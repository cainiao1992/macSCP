//
//  ConnectionCardView.swift
//  macSCP
//
//  Card displaying SSH connection information
//

import SwiftUI

struct ConnectionCardView: View {
    let connection: SSHConnection
    var isSelected: Bool = false
    var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .white : .blue)
                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }

            Text(connection.name)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                    Text(connection.host)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person")
                        .font(.caption)
                    Text(connection.username)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            isSelected ? Color.accentColor : (isHovered ? Color(.controlBackgroundColor).opacity(0.7) : Color(.controlBackgroundColor))
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 2)
    }
}
