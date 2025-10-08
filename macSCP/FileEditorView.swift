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
    @State private var showingFontSizePicker = false
    @State private var showingSearchBar = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var matchCount = 0
    @State private var currentMatchIndex = 0

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
                        if !showingSearchBar {
                            searchText = ""
                            replaceText = ""
                        }
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

                Divider()

                // Search bar
                if showingSearchBar {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))

                            TextField("Find", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .onChange(of: searchText) { _, _ in
                                    updateSearchMatches()
                                }

                            if !searchText.isEmpty {
                                Text("\(currentMatchIndex)/\(matchCount)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 40)

                                Button(action: findPrevious) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .disabled(matchCount == 0)

                                Button(action: findNext) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .disabled(matchCount == 0)
                            }

                            Button(action: {
                                showingSearchBar = false
                                searchText = ""
                                replaceText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))

                            TextField("Replace", text: $replaceText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))

                            Button("Replace") {
                                replaceCurrent()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(matchCount == 0)

                            Button("Replace All") {
                                replaceAll()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(matchCount == 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                    }
                    .background(Color(.controlBackgroundColor))

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
                // Text editor
                ZStack(alignment: .topLeading) {
                    Color(.textBackgroundColor)

                    TextEditor(text: $fileContent)
                        .font(.system(size: fontSize, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                }
            }

            // Status bar
            if !isLoading {
                Divider()
                HStack(spacing: 12) {
                    if hasUnsavedChanges {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.orange)
                            Text("Edited")
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(lineCount) lines")
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("\(characterCount) characters")
                        .foregroundColor(.secondary)

                    Divider()
                        .frame(height: 12)

                    Menu {
                        Button("Small (11pt)") { fontSize = 11 }
                        Button("Medium (13pt)") { fontSize = 13 }
                        Button("Large (15pt)") { fontSize = 15 }
                        Button("Extra Large (17pt)") { fontSize = 17 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "textformat.size")
                            Text("\(Int(fontSize))pt")
                        }
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(.windowBackgroundColor))
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
                    if !showingSearchBar {
                        searchText = ""
                        replaceText = ""
                    }
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

    private func updateSearchMatches() {
        guard !searchText.isEmpty else {
            matchCount = 0
            currentMatchIndex = 0
            return
        }

        let matches = fileContent.ranges(of: searchText, options: .caseInsensitive)
        matchCount = matches.count
        currentMatchIndex = matchCount > 0 ? 1 : 0
    }

    private func findNext() {
        guard matchCount > 0 else { return }
        currentMatchIndex = currentMatchIndex < matchCount ? currentMatchIndex + 1 : 1
    }

    private func findPrevious() {
        guard matchCount > 0 else { return }
        currentMatchIndex = currentMatchIndex > 1 ? currentMatchIndex - 1 : matchCount
    }

    private func replaceCurrent() {
        guard !searchText.isEmpty, matchCount > 0 else { return }

        if let range = fileContent.ranges(of: searchText, options: .caseInsensitive).dropFirst(currentMatchIndex - 1).first {
            fileContent.replaceSubrange(range, with: replaceText)
            updateSearchMatches()
        }
    }

    private func replaceAll() {
        guard !searchText.isEmpty else { return }

        fileContent = fileContent.replacingOccurrences(of: searchText, with: replaceText, options: .caseInsensitive)
        updateSearchMatches()
    }
}

extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }

        return ranges
    }
}
