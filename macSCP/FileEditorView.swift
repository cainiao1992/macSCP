//
//  FileEditorView.swift
//  macSCP
//
//  File editor for remote files
//

import SwiftUI

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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.windowBackgroundColor))

                Divider()
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
