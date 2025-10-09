//
//  FinderStyleBrowserView.swift
//  macSCP
//
//  Finder-style file browser for remote SSH server
//

import SwiftUI
import UniformTypeIdentifiers

enum ViewMode {
    case list
    case grid
    case columns
}

struct FinderStyleBrowserView: View {
    @ObservedObject var sshManager: CitadelSFTPManager
    @StateObject private var clipboard = RemoteClipboard.shared
    @StateObject private var navigationManager: NavigationManager
    @StateObject private var fileOpsManager: FileOperationsManager
    @Environment(\.openWindow) private var openWindow

    let host: String
    let port: Int
    let username: String
    let password: String

    @State private var viewMode: ViewMode = .list
    @State private var selectedFile: RemoteFile?
    @State private var selectedFileId: RemoteFile.ID?
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var showingNewFileDialog = false
    @State private var newFileNameInput = ""
    @State private var showingDeleteConfirmation = false
    @State private var fileToDelete: RemoteFile?
    @State private var showingRenameDialog = false
    @State private var fileToRename: RemoteFile?
    @State private var newFileName = ""

    init(sshManager: CitadelSFTPManager, host: String, port: Int, username: String, password: String) {
        self.sshManager = sshManager
        self.host = host
        self.port = port
        self.username = username
        self.password = password

        _navigationManager = StateObject(wrappedValue: NavigationManager(sshManager: sshManager))
        _fileOpsManager = StateObject(wrappedValue: FileOperationsManager(sshManager: sshManager, clipboard: RemoteClipboard.shared))
    }

    var body: some View {
        Group {
            if sshManager.isConnected {
                NavigationSplitView {
                    FinderSidebar(
                        currentPath: sshManager.currentPath,
                        onNavigate: navigateToDirectory
                    )
                } detail: {
                    detailView
                }
            } else {
                VStack {
                    ProgressView("Connecting to server...")
                        .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            navigationManager.initialize()
        }
        .toolbar {
            navigationToolbar
            pasteToolbar
            actionToolbar
        }
        .alert("New Folder", isPresented: $showingNewFolderDialog) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createFolder()
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("New File", isPresented: $showingNewFileDialog) {
            TextField("File name", text: $newFileNameInput)
            Button("Cancel", role: .cancel) {
                newFileNameInput = ""
            }
            Button("Create") {
                createFile()
            }
        } message: {
            Text("Enter a name for the new file")
        }
        .alert("Error", isPresented: $fileOpsManager.showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(fileOpsManager.errorMessage)
        }
        .alert("Delete \(fileToDelete?.name ?? "file")?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    deleteFile(file)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(fileToDelete?.name ?? "this item")\"? This action cannot be undone.")
        }
        .alert("Rename \(fileToRename?.name ?? "file")", isPresented: $showingRenameDialog) {
            TextField("New name", text: $newFileName)
            Button("Cancel", role: .cancel) {
                fileToRename = nil
                newFileName = ""
            }
            Button("Rename") {
                if let file = fileToRename {
                    renameFile(file)
                }
            }
        } message: {
            Text("Enter a new name for \"\(fileToRename?.name ?? "this item")\"")
        }
    }

    // MARK: - Toolbar Components

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: {
                navigationManager.goBack(onSelection: clearSelection)
            }) {
                Image(systemName: "chevron.left")
            }
            .disabled(!navigationManager.canGoBack)
            .help("Back")

            Button(action: {
                navigationManager.goForward(onSelection: clearSelection)
            }) {
                Image(systemName: "chevron.right")
            }
            .disabled(!navigationManager.canGoForward)
            .help("Forward")
        }
    }

    @ToolbarContentBuilder
    private var pasteToolbar: some ToolbarContent {
        if !clipboard.isEmpty {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: { pasteFiles() }) {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste \(clipboard.fileCount) \(clipboard.fileCount == 1 ? "item" : "items")")
            }
        }
    }

    @ToolbarContentBuilder
    private var actionToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { showingNewFolderDialog = true }) {
                Image(systemName: "folder.badge.plus")
            }
            .help("Create new folder")

            Button(action: { showingNewFileDialog = true }) {
                Image(systemName: "doc.badge.plus")
            }
            .help("Create new file")

            Button(action: { navigationManager.refresh() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    // MARK: - View Components

    private var detailView: some View {
        VStack(spacing: 0) {
            fileListView
            bottomToolbarView
        }
    }

    @ViewBuilder
    private var fileListView: some View {
        ZStack {
            if sshManager.remoteFiles.isEmpty && !sshManager.currentPath.isEmpty && !navigationManager.isNavigating {
                EmptyStateView()
            } else {
                fileList
            }
            overlays
        }
    }

    private var fileList: some View {
        List(sshManager.remoteFiles) { file in
            FinderFileRow(
                file: file,
                selectedFileId: $selectedFileId,
                selectedFile: $selectedFile,
                clipboard: clipboard,
                onNavigate: navigateToDirectory,
                onEdit: openFileEditor,
                onDownload: { fileOpsManager.downloadFile($0) },
                onCopy: { fileOpsManager.copyFile($0) },
                onCut: { fileOpsManager.cutFile($0) },
                onPaste: pasteFiles,
                onRename: { file in
                    fileToRename = file
                    newFileName = file.name
                    showingRenameDialog = true
                },
                onDelete: { file in
                    fileToDelete = file
                    showingDeleteConfirmation = true
                },
                onInfo: openFileInfo
            )
        }
        .listStyle(.inset)
        .onKeyPress(.return) {
            if let file = selectedFile, file.isDirectory {
                navigateToDirectory(file.path)
                return .handled
            }
            return .ignored
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            fileOpsManager.handleDrop(providers: providers)
            return true
        }
    }

    @ViewBuilder
    private var overlays: some View {
        if navigationManager.isNavigating {
            LoadingOverlay()
        }

        if fileOpsManager.isUploading {
            ProgressOverlay(message: fileOpsManager.uploadProgress)
        }

        if fileOpsManager.isDownloading {
            ProgressOverlay(message: fileOpsManager.downloadProgress)
        }
    }

    @ViewBuilder
    private var bottomToolbarView: some View {
        if !sshManager.currentPath.isEmpty {
            Divider()
            BreadcrumbView(pathComponents: navigationManager.pathComponents, onNavigate: navigateToDirectory)
        }

        if !clipboard.isEmpty {
            Divider()
            ClipboardStatusView(clipboard: clipboard)
        }
    }

    // MARK: - Helper Functions

    private func clearSelection() {
        selectedFile = nil
        selectedFileId = nil
    }

    private func navigateToDirectory(_ path: String) {
        navigationManager.navigateToDirectory(path, onSelection: clearSelection)
    }

    private func createFolder() {
        Task {
            navigationManager.isNavigating = true
            defer { navigationManager.isNavigating = false }

            await fileOpsManager.createFolder(name: newFolderName)
            newFolderName = ""
        }
    }

    private func createFile() {
        Task {
            navigationManager.isNavigating = true
            defer { navigationManager.isNavigating = false }

            await fileOpsManager.createFile(name: newFileNameInput)
            newFileNameInput = ""
        }
    }

    private func deleteFile(_ file: RemoteFile) {
        Task {
            navigationManager.isNavigating = true
            defer {
                navigationManager.isNavigating = false
                fileToDelete = nil
            }

            await fileOpsManager.deleteFile(file)
        }
    }

    private func renameFile(_ file: RemoteFile) {
        Task {
            navigationManager.isNavigating = true
            defer {
                navigationManager.isNavigating = false
                fileToRename = nil
                newFileName = ""
            }

            await fileOpsManager.renameFile(file, newName: newFileName)
        }
    }

    private func pasteFiles() {
        Task {
            navigationManager.isNavigating = true
            defer { navigationManager.isNavigating = false }

            await fileOpsManager.pasteFiles()
        }
    }

    private func openFileEditor(_ file: RemoteFile) {
        let editorId = UUID().uuidString
        guard let fileData = try? JSONEncoder().encode(file) else { return }

        let editorInfo: [String: Any] = [
            "file": fileData,
            "host": host,
            "port": port,
            "username": username,
            "password": password
        ]

        UserDefaults.standard.set(editorInfo, forKey: "pendingEditor_\(editorId)")
        openWindow(id: "file-editor", value: editorId)
    }

    private func openFileInfo(_ file: RemoteFile) {
        let infoId = UUID().uuidString
        guard let fileData = try? JSONEncoder().encode(file) else { return }

        UserDefaults.standard.set(fileData, forKey: "pendingFileInfo_\(infoId)")
        openWindow(id: "file-info", value: infoId)
    }
}

#Preview {
    FinderStyleBrowserView(
        sshManager: CitadelSFTPManager(),
        host: "localhost",
        port: 2222,
        username: "testuser",
        password: "password"
    )
}
