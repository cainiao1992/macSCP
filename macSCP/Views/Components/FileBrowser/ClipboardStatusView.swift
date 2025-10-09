//
//  ClipboardStatusView.swift
//  macSCP
//
//  Clipboard status indicator showing copied/cut files
//

import SwiftUI

struct ClipboardStatusView: View {
    @ObservedObject var clipboard: RemoteClipboard

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: clipboard.isCopy ? "doc.on.doc" : "scissors")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(clipboard.displayText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                clipboard.clear()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear clipboard")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.controlBackgroundColor).opacity(0.8))
    }
}
