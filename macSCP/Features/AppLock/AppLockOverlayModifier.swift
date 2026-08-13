//
//  AppLockOverlayModifier.swift
//  macSCP
//
//  View modifier to overlay the app lock screen when locked
//

import SwiftUI

struct AppLockOverlayModifier: ViewModifier {
    @Environment(\.appLockManager) private var appLockManager

    func body(content: Content) -> some View {
        content
            .blur(radius: appLockManager.isLocked ? 20 : 0)
            .allowsHitTesting(!appLockManager.isLocked)
            .overlay {
                if appLockManager.isLocked {
                    AppLockView()
                }
            }
    }
}

extension View {
    func appLockOverlay() -> some View {
        modifier(AppLockOverlayModifier())
    }
}
