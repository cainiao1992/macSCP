//
//  EmptyStateView.swift
//  macSCP
//
//  Empty folder state indicator
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
            Text("This folder is empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}
