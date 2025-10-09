//
//  StatusBarView.swift
//  macSCP
//
//  Status bar showing file statistics and font size control
//

import SwiftUI

struct StatusBarView: View {
    let hasUnsavedChanges: Bool
    let lineCount: Int
    let characterCount: Int
    @Binding var fontSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            if hasUnsavedChanges {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                    Text("Edited")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("\(lineCount) lines")
                .foregroundColor(.secondary)

            Text("•")
                .foregroundColor(.secondary.opacity(0.5))

            Text("\(characterCount) characters")
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 12)

            Menu {
                Button("Small (11pt)") { fontSize = 11 }
                Button("Medium (13pt)") { fontSize = 13 }
                Button("Large (15pt)") { fontSize = 15 }
                Button("Extra Large (17pt)") { fontSize = 17 }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                    Text("\(Int(fontSize))pt")
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(.windowBackgroundColor))
    }
}
