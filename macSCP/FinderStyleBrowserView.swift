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

    let host: String
    let port: Int
    let username: String
    let password: String

    @State private var viewMode: ViewMode = .list
    @State private var selectedFile: RemoteFile?
    @State private var selectedFileId: RemoteFile.ID?
    @State private var lastClickTime: Date?
    @State private var lastClickedId: RemoteFile.ID?
    @State private var navigationHistory: [String] = []
    @State private var historyIndex: Int = -1
    @State private var isNavigating = false
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var fileToDelete: RemoteFile?
    @State private var showingRenameDialog = false
    @State private var fileToRename: RemoteFile?
    @State private var newFileName = ""
    @State private var isUploading = false
    @State private var uploadProgress: String = ""

    var canGoBack: Bool {
        historyIndex > 0 && !isNavigating
    }

    var canGoForward: Bool {
        historyIndex < navigationHistory.count - 1 && !isNavigating
    }

    var pathComponents: [(name: String, path: String)] {
        var result: [(String, String)] = []
        let components = sshManager.currentPath.split(separator: "/")

        if sshManager.currentPath.starts(with: "/") {
            result.append(("Root", "/"))
        }

        for (index, component) in components.enumerated() {
            let currentPath = "/" + components[0...index].joined(separator: "/")
            result.append((String(component), currentPath))
        }

        return result
    }

    var body: some View {
        Group {
            // Main content area
            if sshManager.isConnected {
                NavigationSplitView {
                    // Sidebar
                    FinderSidebar(
                        currentPath: sshManager.currentPath,
                        onNavigate: { path in
                            navigateToDirectory(path)
                        }
                    )
                } detail: {
                    // File list with breadcrumb
                    VStack(spacing: 0) {
                        ZStack {
                            if sshManager.remoteFiles.isEmpty && !sshManager.currentPath.isEmpty && !isNavigating {
                                EmptyStateView()
                            } else {
                                List(sshManager.remoteFiles) { file in
                                Button(action: {
                                    if file.isDirectory {
                                        navigateToDirectory(file.path)
                                    } else {
                                        selectedFileId = file.id
                                        selectedFile = file
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        FileIcon(file: file, size: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .font(.system(size: 13))

                                            if !file.isDirectory {
                                                Text(file.displaySize)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if file.isDirectory {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if file.isDirectory {
                                        Button(action: {
                                            navigateToDirectory(file.path)
                                        }) {
                                            Label("Open", systemImage: "folder.fill")
                                        }
                                        Divider()
                                    } else {
                                        Button(action: {
                                            // Download file action - placeholder
                                        }) {
                                            Label("Download", systemImage: "arrow.down.circle")
                                        }
                                        Divider()
                                    }

                                    Button(action: {
                                        fileToRename = file
                                        newFileName = file.name
                                        showingRenameDialog = true
                                    }) {
                                        Label("Rename", systemImage: "pencil")
                                    }

                                    Button(role: .destructive, action: {
                                        fileToDelete = file
                                        showingDeleteConfirmation = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
                                handleDrop(providers: providers)
                                return true
                            }
                        }

                        // Loading overlay
                        if isNavigating {
                            VStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(12)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                        }

                        // Upload overlay
                        if isUploading {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(uploadProgress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.1))
                        }
                    }

                    // Breadcrumb at bottom
                    if !sshManager.currentPath.isEmpty {
                        Divider()

                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                                        Button(action: {
                                            navigateToDirectory(component.path)
                                        }) {
                                            Text(component.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(index == pathComponents.count - 1 ? .primary : .secondary)
                                        }
                                        .buttonStyle(.plain)

                                        if index < pathComponents.count - 1 {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.controlBackgroundColor))
                    }
                    }
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
            // Initialize navigation history with the starting path
            if navigationHistory.isEmpty && !sshManager.currentPath.isEmpty {
                navigationHistory = [sshManager.currentPath]
                historyIndex = 0
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                .help("Back")

                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                .help("Forward")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingNewFolderDialog = true }) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Create new folder")

                Button(action: {
                    Task {
                        isNavigating = true
                        defer { isNavigating = false }
                        try? await sshManager.listFiles(path: sshManager.currentPath)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
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
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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

    private func navigateToDirectory(_ path: String) {
        // Prevent overlapping navigation requests
        guard !isNavigating else { return }

        // Add to history
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory.removeLast(navigationHistory.count - historyIndex - 1)
        }
        navigationHistory.append(path)
        historyIndex = navigationHistory.count - 1

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                // Clear selection after successful navigation
                await MainActor.run {
                    selectedFile = nil
                    selectedFileId = nil
                }
            } catch {
                print("Failed to navigate: \(error)")
                // Revert history on error
                await MainActor.run {
                    if navigationHistory.count > 1 {
                        navigationHistory.removeLast()
                        historyIndex = navigationHistory.count - 1
                    }
                }
            }
        }
    }

    private func goBack() {
        guard canGoBack, !isNavigating else { return }
        historyIndex -= 1
        let path = navigationHistory[historyIndex]

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                await MainActor.run {
                    selectedFile = nil
                    selectedFileId = nil
                }
            } catch {
                print("Failed to navigate: \(error)")
                await MainActor.run {
                    historyIndex += 1 // Revert on error
                }
            }
        }
    }

    private func goForward() {
        guard canGoForward, !isNavigating else { return }
        historyIndex += 1
        let path = navigationHistory[historyIndex]

        Task {
            isNavigating = true
            defer { isNavigating = false }

            do {
                try await sshManager.changeDirectory(to: path)
                await MainActor.run {
                    selectedFile = nil
                    selectedFileId = nil
                }
            } catch {
                print("Failed to navigate: \(error)")
                await MainActor.run {
                    historyIndex -= 1 // Revert on error
                }
            }
        }
    }

    private func refresh() {
        guard !isNavigating else { return }

        Task {
            isNavigating = true
            defer { isNavigating = false }

            try? await sshManager.listFiles(path: sshManager.currentPath)
        }
    }

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let folderName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderPath = sshManager.currentPath.hasSuffix("/")
            ? "\(sshManager.currentPath)\(folderName)"
            : "\(sshManager.currentPath)/\(folderName)"

        Task {
            isNavigating = true
            defer {
                isNavigating = false
                newFolderName = ""
            }

            do {
                try await sshManager.createDirectory(path: folderPath)
                // Refresh the directory listing
                try await sshManager.listFiles(path: sshManager.currentPath)
            } catch {
                print("Failed to create folder: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to create folder '\(folderName)': \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }

    private func deleteFile(_ file: RemoteFile) {
        Task {
            isNavigating = true
            defer {
                isNavigating = false
                fileToDelete = nil
            }

            do {
                try await sshManager.deleteFile(path: file.path, isDirectory: file.isDirectory)
                // Refresh the directory listing
                try await sshManager.listFiles(path: sshManager.currentPath)
            } catch {
                print("Failed to delete file: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete '\(file.name)': \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }

    private func renameFile(_ file: RemoteFile) {
        guard !newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let trimmedName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Build new path
        let pathComponents = file.path.split(separator: "/")
        let parentPath = pathComponents.dropLast().joined(separator: "/")
        let newPath = parentPath.isEmpty ? "/\(trimmedName)" : "/\(parentPath)/\(trimmedName)"

        Task {
            isNavigating = true
            defer {
                isNavigating = false
                fileToRename = nil
                newFileName = ""
            }

            do {
                try await sshManager.renameFile(from: file.path, to: newPath)
                // Refresh the directory listing
                try await sshManager.listFiles(path: sshManager.currentPath)
            } catch {
                print("Failed to rename file: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to rename '\(file.name)': \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        Task {
            isUploading = true
            uploadProgress = "Preparing upload..."

            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        guard let url = url else { return }

                        Task {
                            await self.uploadItemRecursively(localURL: url, remoteBasePath: self.sshManager.currentPath)
                        }
                    }
                }
            }
        }
    }

    private func uploadItemRecursively(localURL: URL, remoteBasePath: String) async {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: localURL.path, isDirectory: &isDirectory) else {
            return
        }

        let itemName = localURL.lastPathComponent
        let remotePath = remoteBasePath.hasSuffix("/") ? "\(remoteBasePath)\(itemName)" : "\(remoteBasePath)/\(itemName)"

        if isDirectory.boolValue {
            // It's a folder - create it and upload contents
            await MainActor.run {
                uploadProgress = "Creating folder: \(itemName)"
            }

            do {
                // Create the folder on remote server
                try await sshManager.createDirectory(path: remotePath)

                // Get all items in the folder
                let contents = try fileManager.contentsOfDirectory(at: localURL, includingPropertiesForKeys: nil)

                // Upload each item recursively
                for itemURL in contents {
                    await uploadItemRecursively(localURL: itemURL, remoteBasePath: remotePath)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload folder '\(itemName)': \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        } else {
            // It's a file - upload it
            await MainActor.run {
                uploadProgress = "Uploading: \(itemName)"
            }

            do {
                try await sshManager.uploadFile(localURL: localURL, to: remotePath)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload file '\(itemName)': \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }

        // Refresh directory after all uploads complete
        if remoteBasePath == sshManager.currentPath {
            await MainActor.run {
                uploadProgress = "Refreshing..."
            }

            try? await sshManager.listFiles(path: sshManager.currentPath)

            await MainActor.run {
                isUploading = false
                uploadProgress = ""
            }
        }
    }
}

// MARK: - Toolbar
struct FinderToolbar: View {
    @Binding var viewMode: ViewMode
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onNewFolder: () -> Void
    let onRefresh: () -> Void
    let currentPath: String

    var body: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)
            .help("Back")

            Button(action: onForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)
            .help("Forward")

            Divider()
                .frame(height: 16)

            Spacer()

            // Actions
            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .help("Create new folder")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Sidebar
struct FinderSidebar: View {
    let currentPath: String
    let onNavigate: (String) -> Void

    var body: some View {
        List {
            Section("Favorites") {
                Label("Home", systemImage: "house.fill")
                    .onTapGesture { onNavigate("~") }

                Label("Root", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/") }
            }

            Section("Locations") {
                Label("etc", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/etc") }

                Label("var", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/var") }

                Label("usr", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/usr") }

                Label("tmp", systemImage: "folder.fill")
                    .onTapGesture { onNavigate("/tmp") }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Breadcrumb
struct PathBreadcrumb: View {
    let path: String
    let onNavigate: (String) -> Void

    var pathComponents: [(name: String, path: String)] {
        var result: [(String, String)] = []
        let components = path.split(separator: "/")

        result.append(("Root", "/"))

        for (index, component) in components.enumerated() {
            let currentPath = "/" + components[0...index].joined(separator: "/")
            result.append((String(component), currentPath))
        }

        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    Button(action: {
                        onNavigate(component.path)
                    }) {
                        Text(component.name)
                            .font(.system(size: 12))
                            .foregroundColor(index == pathComponents.count - 1 ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)

                    if index < pathComponents.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - List View
struct ListViewMode: View {
    let files: [RemoteFile]
    @Binding var selectedFile: RemoteFile?
    let onNavigate: (String) -> Void
    let onDelete: (RemoteFile) -> Void
    let onRename: (RemoteFile) -> Void

    @State private var selection = Set<RemoteFile.ID>()
    @State private var lastClickTime: Date?
    @State private var lastClickedId: RemoteFile.ID?

    var body: some View {
        Table(files, selection: $selection) {
            TableColumn("Name") { file in
                Button(action: {
                    handleFileClick(file)
                }) {
                    HStack(spacing: 8) {
                        FileIcon(file: file)
                        Text(file.name)
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if file.isDirectory {
                        Button(action: {
                            onNavigate(file.path)
                        }) {
                            Label("Open", systemImage: "folder.fill")
                        }
                        Divider()
                    } else {
                        Button(action: {
                            // Download file action - placeholder
                        }) {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        Divider()
                    }

                    Button(action: {
                        onRename(file)
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: {
                        onDelete(file)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Size") { file in
                Text(file.displaySize)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .width(80)

            TableColumn("Permissions") { file in
                Text(file.permissions)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(100)
        }
        .onChange(of: selection) { oldValue, newValue in
            if let id = newValue.first {
                selectedFile = files.first { $0.id == id }
            }
        }
        .onKeyPress(.return) {
            if let file = selectedFile, file.isDirectory {
                onNavigate(file.path)
                return .handled
            }
            return .ignored
        }
    }

    private func handleFileClick(_ file: RemoteFile) {
        let now = Date()

        // Check if this is a double-click (within 0.5 seconds)
        if let lastTime = lastClickTime,
           let lastId = lastClickedId,
           lastId == file.id,
           now.timeIntervalSince(lastTime) < 0.5 {
            // Double-click detected
            if file.isDirectory {
                onNavigate(file.path)
            }
            lastClickTime = nil
            lastClickedId = nil
        } else {
            // Single click - just select
            selectedFile = file
            selection = [file.id]
            lastClickTime = now
            lastClickedId = file.id
        }
    }
}

// MARK: - Grid View
struct GridViewMode: View {
    let files: [RemoteFile]
    @Binding var selectedFile: RemoteFile?
    let onNavigate: (String) -> Void
    let onDelete: (RemoteFile) -> Void
    let onRename: (RemoteFile) -> Void

    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(files) { file in
                    GridFileItem(file: file, isSelected: selectedFile?.id == file.id)
                        .onTapGesture {
                            selectedFile = file
                        }
                        .onTapGesture(count: 2) {
                            if file.isDirectory {
                                onNavigate(file.path)
                            }
                        }
                        .contextMenu {
                            if file.isDirectory {
                                Button("Open") {
                                    onNavigate(file.path)
                                }
                                Divider()
                            }
                            Button("Rename") {
                                onRename(file)
                            }
                            Button("Delete", role: .destructive) {
                                onDelete(file)
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct GridFileItem: View {
    let file: RemoteFile
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            FileIcon(file: file, size: 48)

            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30)
        }
        .frame(width: 100, height: 100)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Column View
struct ColumnViewMode: View {
    let files: [RemoteFile]
    let currentPath: String
    @Binding var selectedFile: RemoteFile?
    let onNavigate: (String) -> Void
    let onDelete: (RemoteFile) -> Void
    let onRename: (RemoteFile) -> Void

    @State private var lastClickTime: Date?
    @State private var lastClickedId: RemoteFile.ID?

    var body: some View {
        HStack(spacing: 0) {
            // Files column
            List(files, selection: $selectedFile) { file in
                Button(action: {
                    handleFileClick(file)
                }) {
                    HStack {
                        FileIcon(file: file)
                        Text(file.name)
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if file.isDirectory {
                        Button(action: {
                            onNavigate(file.path)
                        }) {
                            Label("Open", systemImage: "folder.fill")
                        }
                        Divider()
                    } else {
                        Button(action: {
                            // Download file action - placeholder
                        }) {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        Divider()
                    }

                    Button(action: {
                        onRename(file)
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: {
                        onDelete(file)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .listStyle(.plain)

            // Preview/details column
            if let file = selectedFile {
                FileDetailsPanel(file: file)
                    .frame(width: 250)
            }
        }
    }

    private func handleFileClick(_ file: RemoteFile) {
        let now = Date()

        // Check if this is a double-click (within 0.5 seconds)
        if let lastTime = lastClickTime,
           let lastId = lastClickedId,
           lastId == file.id,
           now.timeIntervalSince(lastTime) < 0.5 {
            // Double-click detected
            if file.isDirectory {
                onNavigate(file.path)
            }
            lastClickTime = nil
            lastClickedId = nil
        } else {
            // Single click - just select
            selectedFile = file
            lastClickTime = now
            lastClickedId = file.id
        }
    }
}

struct FileDetailsPanel: View {
    let file: RemoteFile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                FileIcon(file: file, size: 64)
                Spacer()
            }

            Text(file.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Type", value: file.isDirectory ? "Folder" : "File")
                DetailRow(label: "Size", value: file.displaySize)
                DetailRow(label: "Permissions", value: file.permissions)
                if let date = file.modificationDate {
                    DetailRow(label: "Modified", value: date.formatted())
                }
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - File Icon
struct FileIcon: View {
    let file: RemoteFile
    var size: CGFloat = 20

    var iconName: String {
        if file.isDirectory {
            return "folder.fill"
        }

        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "svg":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        case "pdf":
            return "doc.fill"
        case "sh", "bash", "zsh":
            return "terminal.fill"
        case "py", "js", "java", "swift", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        if file.isDirectory {
            return .blue
        }

        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "svg":
            return .orange
        case "mp4", "mov", "avi", "mkv":
            return .purple
        case "mp3", "wav", "aac", "flac":
            return .pink
        case "zip", "tar", "gz", "rar", "7z":
            return .gray
        case "pdf":
            return .red
        case "sh", "bash", "zsh":
            return .green
        case "py", "js", "java", "swift", "cpp", "c", "h":
            return .blue
        default:
            return .gray
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundColor(iconColor)
            .symbolRenderingMode(.hierarchical)
            .frame(width: size, height: size)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.5))
                .symbolRenderingMode(.hierarchical)
            Text("This folder is empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
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
