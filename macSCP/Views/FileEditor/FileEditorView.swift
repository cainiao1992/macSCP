//
//  FileEditorView.swift
//  macSCP
//
//  File editor for remote files
//

import SwiftUI

struct FileEditorWindowView: View {
    let editorId: String

    @State private var fileInfo: FileEditorInfo?
    @StateObject private var sshManager = CitadelSFTPManager()
    @State private var isConnecting = true
    @State private var connectionError: String?

    struct FileEditorInfo {
        let file: RemoteFile
        let host: String
        let port: Int
        let username: String
        let password: String
    }

    var body: some View {
        Group {
            if isConnecting {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to server...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let error = connectionError {
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Connection Failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let fileInfo = fileInfo, sshManager.isConnected {
                FileEditorView(file: fileInfo.file, sshManager: sshManager)
            }
        }
        .onAppear {
            loadEditorInfo()
        }
        .onDisappear {
            Task {
                await sshManager.disconnect()
            }
            // Clean up stored info
            UserDefaults.standard.removeObject(forKey: "pendingEditor_\(editorId)")
        }
    }

    private func loadEditorInfo() {
        guard let storedInfo = UserDefaults.standard.dictionary(forKey: "pendingEditor_\(editorId)") else {
            connectionError = "Failed to load editor information"
            isConnecting = false
            return
        }

        guard let fileData = storedInfo["file"] as? Data,
              let file = try? JSONDecoder().decode(RemoteFile.self, from: fileData),
              let host = storedInfo["host"] as? String,
              let port = storedInfo["port"] as? Int,
              let username = storedInfo["username"] as? String,
              let password = storedInfo["password"] as? String else {
            connectionError = "Invalid editor information"
            isConnecting = false
            return
        }

        let info = FileEditorInfo(
            file: file,
            host: host,
            port: port,
            username: username,
            password: password
        )

        fileInfo = info

        // Connect SSH manager
        Task {
            do {
                try await sshManager.connect(host: host, port: port, username: username, password: password)
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    connectionError = error.localizedDescription
                    isConnecting = false
                }
            }
        }
    }
}

struct FileEditorView: View {
    let file: RemoteFile
    let sshManager: CitadelSFTPManager

    @Environment(\.dismiss) private var dismiss

    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingUnsavedChangesAlert = false
    @State private var fontSize: CGFloat = 13
    @State private var showingSearchBar = false

    @StateObject private var searchManager = SearchManager()

    var hasUnsavedChanges: Bool {
        fileContent != originalContent
    }

    var lineCount: Int {
        fileContent.components(separatedBy: .newlines).count
    }

    var characterCount: Int {
        fileContent.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // File info header
            if !isLoading {
                EditorHeaderView(file: file, showingSearchBar: $showingSearchBar)
                    .onChange(of: showingSearchBar) { _, newValue in
                        if !newValue {
                            searchManager.reset()
                        }
                    }

                Divider()

                // Search bar
                if showingSearchBar {
                    SearchBarView(
                        searchText: $searchManager.searchText,
                        replaceText: $searchManager.replaceText,
                        showingSearchBar: $showingSearchBar,
                        matchCount: searchManager.matchCount,
                        currentMatchIndex: searchManager.currentMatchIndex,
                        onFindNext: { searchManager.findNext() },
                        onFindPrevious: { searchManager.findPrevious() },
                        onReplaceCurrent: { searchManager.replaceCurrent(in: &fileContent) },
                        onReplaceAll: { searchManager.replaceAll(in: &fileContent) }
                    )
                    .onChange(of: searchManager.searchText) { _, _ in
                        searchManager.updateSearchMatches(in: fileContent)
                    }

                    Divider()
                }
            }

            // Editor
            if isLoading {
                VStack {
                    ProgressView("Loading file...")
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EditorContentView(
                    fileContent: $fileContent,
                    fontSize: fontSize,
                    showingSearchBar: showingSearchBar,
                    searchManager: searchManager
                )
            }

            // Status bar
            if !isLoading {
                Divider()
                StatusBarView(
                    hasUnsavedChanges: hasUnsavedChanges,
                    lineCount: lineCount,
                    characterCount: characterCount,
                    fontSize: $fontSize
                )
            }
        }
        .navigationTitle(file.name)
        .navigationSubtitle(file.path)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    handleCancel()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingSearchBar.toggle()
                }) {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
                .help("Find and Replace (⌘F)")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    saveFile()
                }
                .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        .onAppear {
            loadFile()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Don't Save", role: .destructive) {
                dismiss()
            }
            Button("Save") {
                saveFile()
            }
        } message: {
            Text("Do you want to save the changes you made to \"\(file.name)\"?")
        }
    }

    private func handleCancel() {
        if hasUnsavedChanges {
            showingUnsavedChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func loadFile() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(file.name)

                // Download file
                try await sshManager.downloadFile(remotePath: file.path, to: tempFile)

                // Read content
                let content = try String(contentsOf: tempFile, encoding: .utf8)

                await MainActor.run {
                    fileContent = content
                    originalContent = content
                }

                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load file: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func saveFile() {
        Task {
            isSaving = true
            defer { isSaving = false }

            do {
                // Create temporary file with content
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(file.name)

                try fileContent.write(to: tempFile, atomically: true, encoding: .utf8)

                // Upload file
                try await sshManager.uploadFile(localURL: tempFile, to: file.path)

                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFile)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save file: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}
