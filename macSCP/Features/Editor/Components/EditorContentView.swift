//
//  EditorContentView.swift
//  macSCP
//
//  Text editor content view
//

import SwiftUI

struct EditorContentView: View {
    @Bindable var viewModel: FileEditorViewModel

    var body: some View {
        SyntaxHighlightingTextView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    EditorContentView(viewModel: FileEditorViewModel(
        filePath: "/test.txt",
        fileName: "test.txt",
        initialContent: """
        function hello() {
            console.log("Hello, World!");
        }

        hello();
        """,
        fileRepository: FileRepository(sftpSession: SystemSFTPSession())
    ))
}
