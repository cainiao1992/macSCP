//
//  LoadingView.swift
//  macSCP
//
//  Reusable loading indicator view - Modern macOS style
//

import SwiftUI

struct LoadingView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Inline Loading
struct InlineLoadingView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous))
    }
}

// MARK: - Preview
#Preview("Loading View") {
    LoadingView(message: "Connecting...")
        .frame(width: 300, height: 200)
}

#Preview("Inline Loading") {
    InlineLoadingView(message: "Refreshing...")
        .padding()
}
