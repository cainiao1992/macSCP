//
//  EditorHeaderView.swift
//  macSCP
//
//  File editor header showing file info and search toggle
//

import SwiftUI

struct EditorHeaderView: View {
    let file: RemoteFile
    @Binding var showingSearchBar: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(file.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Search toggle button
            Button(action: {
                showingSearchBar.toggle()
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(showingSearchBar ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Find and Replace (⌘F)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor))
    }
}
