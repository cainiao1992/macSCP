//
//  FileEditorView.swift
//  macSCP
//
//  Main file editor view
//

import SwiftUI

struct FileEditorView: View {
    @Bindable var viewModel: FileEditorViewModel
    @State private var isSaving = false

    init(viewModel: FileEditorViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            EditorHeaderView(viewModel: viewModel)

            Divider()

            // Search bar (conditional)
            if viewModel.isShowingSearch {
                SearchReplaceBar(viewModel: viewModel)
                Divider()
            }

            // Editor content
            EditorContentView(viewModel: viewModel)

            Divider()

            // Status bar
            EditorStatusBar(viewModel: viewModel)
        }
        .frame(minWidth: WindowSize.fileEditor.width, minHeight: WindowSize.fileEditor.height)
        .errorAlert($viewModel.error)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.toggleSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
                .help("Find and Replace")
                .accessibilityLabel("Find and Replace")

                Button {
                    save()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.hasChanges || isSaving)
                .help("Save")
                .accessibilityLabel("Save")
            }
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
    FileEditorView(viewModel: FileEditorViewModel(
        filePath: "/home/user/test.txt",
        fileName: "test.txt",
        initialContent: "Hello, World!\n\nThis is a test file.",
        fileRepository: FileRepository(sftpSession: SystemSFTPSession())
    ))
}
