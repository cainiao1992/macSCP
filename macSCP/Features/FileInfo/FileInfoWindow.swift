//
//  FileInfoWindow.swift
//  macSCP
//
//  Window wrapper for file info
//

import SwiftUI

struct FileInfoWindow: View {
    let windowId: String
    @State private var viewModel: FileInfoViewModel?
    @State private var showMissingDataError = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.windowManager) private var windowManager

    var body: some View {
        Group {
            if showMissingDataError {
                SessionExpiredView(message: "This window's data was lost.") {
                    dismiss()
                }
            } else if let viewModel = viewModel {
                FileInfoView(viewModel: viewModel)
                    .navigationTitle("Info - \(viewModel.fileName)")
            } else {
                LoadingView(message: "Loading...")
                    .task {
                        initializeViewModel()
                    }
            }
        }
        .frame(width: WindowSize.fileInfo.width, height: WindowSize.fileInfo.height)
    }

    @MainActor
    private func initializeViewModel() {
        guard let data = windowManager.getFileInfoData(for: windowId) else {
            logError("No file info data found for ID: \(windowId)", category: .ui)
            showMissingDataError = true
            return
        }

        viewModel = FileInfoViewModel(
            file: data.file,
            connectionName: data.connectionName
        )
    }
}

// MARK: - Preview
#Preview {
    FileInfoWindow(windowId: "preview")
}
