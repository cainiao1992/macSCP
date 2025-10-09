//
//  OverlayViews.swift
//  macSCP
//
//  Loading and progress overlay components
//

import SwiftUI

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(0.8)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }
}

// MARK: - Progress Overlay
struct ProgressOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }
}
