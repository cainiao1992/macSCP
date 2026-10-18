//
//  SessionExpiredView.swift
//  macSCP
//
//  Shown when a secondary window loses its session data (e.g. after app restart).
//

import SwiftUI

struct SessionExpiredView: View {
    var message: String = "This window's session data was lost. Please reconnect from the main window."
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: UIConstants.spacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Session Expired")
                .font(.headline)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Close Window") {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(UIConstants.xlSpacing)
    }
}

// MARK: - Preview

#Preview {
    SessionExpiredView(onClose: {})
        .frame(width: 320, height: 240)
}
