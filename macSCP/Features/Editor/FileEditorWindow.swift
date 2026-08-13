//
//  FileEditorWindow.swift
//  macSCP
//
//  Window wrapper for the file editor
//

import SwiftUI

struct FileEditorWindow: View {
    let windowId: String
    @State private var viewModel: FileEditorViewModel?
    @State private var isConnecting = true
    @State private var connectionError: AppError?
    @State private var showMissingDataError = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowManager) private var windowManager
    @Environment(\.makeFileEditorDependencies) private var makeFileEditorDependencies

    var body: some View {
        Group {
            if showMissingDataError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Session Expired")
                        .font(.headline)
                    Text("This editor's session data was lost. Please reopen the file from the browser.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close Window") {
                        dismiss()
                    }
                }
                .padding(32)
            } else if let viewModel = viewModel {
                FileEditorView(viewModel: viewModel)
                    .navigationTitle(viewModel.fileName)
            } else if let error = connectionError {
                ErrorView(error: error) {
                    Task {
                        await initializeViewModel()
                    }
                }
            } else {
                LoadingView(message: "Connecting...")
                    .task {
                        await initializeViewModel()
                    }
            }
        }
        .frame(minWidth: WindowSize.fileEditor.width, minHeight: WindowSize.fileEditor.height)
        .onDisappear {
            Task {
                await viewModel?.cleanup()
            }
        }
    }

    @MainActor
    private func initializeViewModel() async {
        guard let data = windowManager.getFileEditorData(for: windowId) else {
            logError("No editor data found for ID: \(windowId)", category: .ui)
            showMissingDataError = true
            return
        }

        do {
            // Session creation + connect logic is encapsulated in the injected
            // factory closure (built at the composition root) so this Window
            // never reaches into DependencyContainer directly.
            let (fileRepository, s3Session, sftpSession) = try await makeFileEditorDependencies(data)

            viewModel = FileEditorViewModel(
                filePath: data.filePath,
                fileName: data.fileName,
                initialContent: data.content,
                fileRepository: fileRepository,
                s3Session: s3Session,
                sftpSession: sftpSession
            )
        } catch {
            logError("Failed to connect for editor: \(error)", category: data.connectionType == .s3 ? .s3 : .sftp)
            connectionError = AppError.from(error)
        }
    }
}

// MARK: - Preview
#Preview {
    FileEditorWindow(windowId: "preview")
}
