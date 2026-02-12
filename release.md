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
