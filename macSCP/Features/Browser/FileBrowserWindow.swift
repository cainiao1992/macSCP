//
//  FileBrowserWindow.swift
//  macSCP
//
//  Window wrapper for the file browser
//

import SwiftUI

struct FileBrowserWindow: View {
    let windowId: String
    @State private var viewModel: FileBrowserViewModel?
    @State private var showMissingDataError = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowManager) private var windowManager
    @Environment(\.makeFileBrowserViewModel) private var makeFileBrowserViewModel
    @Environment(\.makeS3FileBrowserViewModel) private var makeS3FileBrowserViewModel
    @Environment(\.makeS3Session) private var makeS3Session
    @Environment(\.makeSFTPSession) private var makeSFTPSessionFactory

    var body: some View {
        Group {
            if showMissingDataError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Session Expired")
                        .font(.headline)
                    Text("This window's session data was lost. Please reconnect from the main window.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close Window") {
                        dismiss()
                    }
                }
                .padding(32)
            } else if let viewModel = viewModel {
                FileBrowserView(viewModel: viewModel)
                    .navigationTitle(viewModel.connection.name)
            } else {
                LoadingView(message: "Initializing...")
                    .task {
                        initializeViewModel()
                    }
            }
        }
        .frame(minWidth: WindowSize.minFileBrowser.width, minHeight: WindowSize.minFileBrowser.height)
    }

    @MainActor
    private func initializeViewModel() {
        guard let data = windowManager.getFileBrowserData(for: windowId) else {
            logError("No window data found for ID: \(windowId)", category: .ui)
            showMissingDataError = true
            return
        }

        let connection = Connection(
            id: data.connectionId,
            name: data.connectionName,
            host: data.host,
            port: data.port,
            username: data.username,
            authMethod: data.authMethod,
            privateKeyPath: data.privateKeyPath,
            connectionType: data.connectionType,
            s3Region: data.s3Region,
            s3Bucket: data.s3Bucket,
            s3Endpoint: data.s3Endpoint
        )

        if data.connectionType == .s3 {
            // S3 connection
            let s3Session = makeS3Session()
            viewModel = makeS3FileBrowserViewModel(
                connection,
                s3Session,
                data.s3SecretAccessKey ?? data.password
            )
        } else {
            // SFTP connection
            let sftpSession = makeSFTPSessionFactory(data.privateKeyPath)
            viewModel = makeFileBrowserViewModel(
                connection,
                sftpSession,
                data.password
            )
        }
    }
}

// MARK: - Preview
#Preview {
    FileBrowserWindow(windowId: "preview")
}
