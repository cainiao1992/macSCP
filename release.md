# 📋 Changelog v0.2.5

## ✨ New Features

- **🔐 Touch ID & Biometric Authentication** - Protect your sessions with Touch ID. Lock macSCP on launch, when switching apps, before each connection, or after a configurable inactivity timeout (1 min to 1 hour). All windows are blurred and gated behind authentication when locked.
- **⚙️ Settings Window** - A new Settings window (Cmd+,) gives you a central place to configure security preferences including all Touch ID lock options.

## 🚀 Improvements

- 📐 Sidebar now has a wider default width and supports resizing with constrained min/max bounds for a better layout experience
- 📂 Navigation split view column visibility is now fixed so the sidebar always stays visible

## 🔧 Under the Hood

- Added `BiometricAuthService` backed by LocalAuthentication framework with full `LAContext` lifecycle management
- Added `AppLockManager` as an `@Observable` singleton managing lock state, inactivity timers, and app-resume observers
- Connections and terminal sessions now gate behind biometric auth when "Require before each connection" is enabled
- Added `.auth` log category and biometric analytics events
- Licensed the project under CC0 1.0 Universal

---

# 📋 Changelog v0.2.4

## ✨ New Features

- **🔄 Automatic Updates** - macSCP now checks for updates automatically in the background and notifies you when a new version is available. You can also manually check via "Check for Updates..." in the macSCP menu.

## 🐛 Bug Fixes

- Fixed a potential UI threading issue in the file browser table view

## 🔧 Under the Hood

- Integrated Sparkle framework for secure update delivery with EdDSA-signed packages
- Added appcast.xml feed for update distribution
- App version is now stamped dynamically from git tags at build time
- Improved CI release workflow with automated DMG signing and appcast generation
