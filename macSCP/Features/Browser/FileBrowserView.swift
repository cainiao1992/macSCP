//
//  FileBrowserView.swift
//  macSCP
//
//  Main file browser view
//

import SwiftUI

struct FileBrowserView: View {
    @Bindable var viewModel: FileBrowserViewModel
    @Environment(\.openWindow) private var openWindow
    
    init(viewModel: FileBrowserViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        browserChrome
            .task {
                await viewModel.connect()
            }
            .sheet(isPresented: $viewModel.isShowingNewFolderSheet) {
                NameInputSheet.newFolder(
                    onConfirm: { name in
                        Task {
                            await viewModel.createFolder(name: name)
                        }
                    },
                    onCancel: {
                        viewModel.isShowingNewFolderSheet = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.isShowingNewFileSheet) {
                NameInputSheet.newFile(
                    onConfirm: { name in
                        Task {
                            await viewModel.createFile(name: name)
                        }
                    },
                    onCancel: {
                        viewModel.isShowingNewFileSheet = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.isShowingRenameSheet) {
                if let file = viewModel.fileToRename {
                    NameInputSheet.rename(
                        currentName: file.name,
                        onConfirm: { newName in
                            Task {
                                await viewModel.renameFile(file, to: newName)
                            }
                        },
                        onCancel: {
                            viewModel.isShowingRenameSheet = false
                            viewModel.fileToRename = nil
                        }
                    )
                }
            }
            .alert("Delete Files", isPresented: $viewModel.isShowingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteFiles(viewModel.filesToDelete)
                    }
                }
            } message: {
                let count = viewModel.filesToDelete.count
                Text("Are you sure you want to delete \(count) item\(count == 1 ? "" : "s")? This cannot be undone.")
            }
            .errorAlert($viewModel.error)
            .alert("Host Key Changed", isPresented: $viewModel.isShowingHostKeyMismatchAlert) {
                Button("Disconnect", role: .cancel) {
                    viewModel.disconnectAfterHostKeyMismatch()
                }
                Button("Replace Key & Connect", role: .destructive) {
                    Task {
                        await viewModel.replaceHostKeyAndConnect()
                    }
                }
            } message: {
                Text("The server's host key for \(viewModel.connection.host):\(viewModel.connection.port) has changed. This may indicate the server has been reconfigured, or it could be a security concern.\n\nWould you like to replace the stored key and connect, or disconnect?")
            }
            .onDisappear {
                Task {
                    await viewModel.disconnect()
                }
            }
            .onChange(of: viewModel.pendingFileInfoWindowId) { _, windowId in
                if let windowId = windowId {
                    openWindow(id: WindowID.fileInfo, value: windowId)
                    viewModel.clearPendingFileInfoWindow()
                }
            }
            .onChange(of: viewModel.pendingEditorWindowId) { _, windowId in
                if let windowId = windowId {
                    openWindow(id: WindowID.fileEditor, value: windowId)
                    viewModel.clearPendingEditorWindow()
                }
            }
            .onChange(of: viewModel.pendingTerminalWindowId) { _, windowId in
                if let windowId = windowId {
                    openWindow(id: WindowID.terminal, value: windowId)
                    viewModel.clearPendingTerminalWindow()
                }
            }
    }
    
    private var browserChrome: some View {
        browserLayout
            .frame(minWidth: WindowSize.minFileBrowser.width, minHeight: WindowSize.minFileBrowser.height)
            .navigationTitle(viewModel.currentPath == "/" ? viewModel.connection.name : (viewModel.currentPath as NSString).lastPathComponent)
            .navigationSubtitle(viewModel.isConnected ? viewModel.connection.connectionString : "Disconnected")
            .accessibilityIdentifier("fileBrowser")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        Task { await viewModel.goHome() }
                    } label: {
                        Image(systemName: "house")
                    }
                    .disabled(!viewModel.isConnected)
                    .help("Go Home")
                    
                    Button {
                        Task { await viewModel.goBack() }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!viewModel.canGoBack)
                    .help("Go Back")
                    
                    Button {
                        Task { await viewModel.goForward() }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!viewModel.canGoForward)
                    .help("Go Forward")
                    
                    Button {
                        Task { await viewModel.goUp() }
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!viewModel.canGoUp)
                    .help("Go Up")
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    primaryActions
                }
            }
    }
    
    @ViewBuilder
    private var primaryActions: some View {
        Menu {
            Button {
                viewModel.isShowingNewFolderSheet = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .accessibilityIdentifier("newFolderButton")

            Button {
                viewModel.isShowingNewFileSheet = true
            } label: {
                Label("New File", systemImage: "doc.badge.plus")
            }
            .accessibilityIdentifier("newFileButton")
        } label: {
            Label("New", systemImage: "plus")
        }
        .help("New File or Folder")
        .accessibilityIdentifier("newButton")

        Button {
            Task { await viewModel.uploadFiles() }
        } label: {
            Label("Upload", systemImage: "square.and.arrow.up")
        }
        .help("Upload Files")
        .accessibilityIdentifier("uploadButton")

        Button {
            viewModel.confirmDeleteSelected()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(viewModel.selectedFiles.isEmpty)
        .help("Delete Selected")
        .accessibilityIdentifier("deleteButton")
        
        Spacer()
        
        if viewModel.connection.connectionType == .sftp {
            Button {
                viewModel.openTerminal()
            } label: {
                Label("Terminal", systemImage: "terminal")
            }
            .disabled(!viewModel.isConnected)
            .help("Open Terminal")
        }
        
        TransfersToolbarButton(viewModel: viewModel)
        
        Toggle(isOn: $viewModel.showHiddenFiles) {
            Label(
                viewModel.showHiddenFiles ? "Hide Hidden Files" : "Show Hidden Files",
                systemImage: viewModel.showHiddenFiles ? "eye.fill" : "eye.slash"
            )
        }
        .help("Toggle Hidden Files")
        
        Menu {
            ForEach(RemoteFile.SortCriteria.allCases, id: \.self) { criteria in
                Button {
                    if viewModel.sortCriteria == criteria {
                        viewModel.sortAscending.toggle()
                    } else {
                        viewModel.sortCriteria = criteria
                        viewModel.sortAscending = true
                    }
                } label: {
                    HStack {
                        Text(criteria.rawValue)
                        if viewModel.sortCriteria == criteria {
                            Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .help("Sort Options")
    }
    
    private var browserLayout: some View {
        VStack(spacing: 0) {
            BreadcrumbView(
                components: viewModel.pathComponents,
                onNavigate: { path in
                    Task {
                        await viewModel.navigateTo(path)
                    }
                }
            )
            
            Divider()
            
            contentView
            
            Divider()
            
            statusBar
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: viewModel.isConnected ? "Loading..." : "Connecting...")
            
        case .success:
            FileListView(
                viewModel: viewModel,
                onOpenEditor: openFileInEditor,
                onGetInfo: showFileInfo
            )
            
        case .error(let error):
            ErrorView(error: error) {
                Task {
                    if viewModel.isConnected {
                        await viewModel.refresh()
                    } else {
                        await viewModel.connect()
                    }
                }
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Connection status
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                
                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Active transfers indicator (clicking opens the popover)
            if viewModel.hasActiveTransfers {
                ActiveTransfersIndicator(viewModel: viewModel)
            }
            
            // Clipboard status
            if viewModel.hasClipboardItems && !viewModel.hasActiveTransfers {
                ClipboardStatusView(displayText: viewModel.clipboardDisplayText)
            }
            
            Spacer()
            
            // File count
            HStack(spacing: 6) {
                Text("\(viewModel.sortedFiles.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                if !viewModel.selectedFiles.isEmpty {
                    Text("\(viewModel.selectedFiles.count) selected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    private func openFileInEditor(_ file: RemoteFile) {
        Task {
            do {
                let content = try await viewModel.getFileContent(file)
                viewModel.openEditor(for: file, content: content)
            } catch {
                viewModel.error = AppError.from(error)
            }
        }
    }
    
    private func showFileInfo(_ file: RemoteFile) {
        viewModel.showFileInfo(file)
    }
}

// MARK: - Clipboard Status View
struct ClipboardStatusView: View {
    let displayText: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            Text(displayText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Active Transfers Indicator
struct ActiveTransfersIndicator: View {
    @Bindable var viewModel: FileBrowserViewModel
    
    var body: some View {
        Button {
            viewModel.isShowingTransfersPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 50)
                
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    FileBrowserView(
        viewModel: DependencyContainer.shared.makeFileBrowserViewModel(
            connection: Connection(name: "Test", host: "localhost", username: "user"),
            sftpSession: SystemSFTPSession(),
            password: "test"
        )
    )
}
