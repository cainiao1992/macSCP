//
//  EditorHeaderView.swift
//  macSCP
//
//  Header view for the file editor
//

import SwiftUI

struct EditorHeaderView: View {
    @Bindable var viewModel: FileEditorViewModel

    @State private var isConfirmingReload = false
    @State private var isConfirmingRevert = false
    @State private var isSaving = false

    var body: some View {
        HStack {
            // File info
            HStack(spacing: UIConstants.smallSpacing) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(viewModel.fileName)
                    .font(.headline)

                if viewModel.hasChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Unsaved changes")
                }
            }

            Spacer()

            // Actions
            HStack(spacing: UIConstants.smallSpacing) {
                Button {
                    if viewModel.hasChanges {
                        isConfirmingReload = true
                    } else {
                        Task { await viewModel.reload() }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isSaving)
                .help("Reload from server")
                .accessibilityLabel("Reload from server")

                Button {
                    if viewModel.hasChanges {
                        isConfirmingRevert = true
                    } else {
                        viewModel.revertChanges()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.hasChanges || isSaving)
                .help("Revert changes")
                .accessibilityLabel("Revert changes")

                Button {
                    save()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(!viewModel.hasChanges || isSaving)
                .help("Save")
                .accessibilityLabel("Save")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, UIConstants.smallSpacing)
        .background(Color(.windowBackgroundColor))
        .confirmationDialog(
            "Reload from Server",
            isPresented: $isConfirmingReload,
            titleVisibility: .visible
        ) {
            Button("Discard Changes & Reload", role: .destructive) {
                Task { await viewModel.reload() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reloading will discard your unsaved changes to \"\(viewModel.fileName)\".")
        }
        .confirmationDialog(
            "Revert Changes",
            isPresented: $isConfirmingRevert,
            titleVisibility: .visible
        ) {
            Button("Revert Changes", role: .destructive) {
                viewModel.revertChanges()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will discard your unsaved changes to \"\(viewModel.fileName)\".")
        }
    }

    private func save() {
        guard !isSaving else { return }
        Task {
            isSaving = true
            await viewModel.save()
            isSaving = false
        }
    }
}

// MARK: - Preview
#Preview {
    EditorHeaderView(viewModel: FileEditorViewModel(
        filePath: "/test.txt",
        fileName: "test.txt",
        initialContent: "Hello",
        fileRepository: FileRepository(sftpSession: SystemSFTPSession())
    ))
}
