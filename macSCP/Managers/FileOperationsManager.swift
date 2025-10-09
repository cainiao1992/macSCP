//
//  FileOperationsManager.swift
//  macSCP
//
//  Manager for handling file operations (create, delete, rename, copy, paste, upload, download)
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FileOperationsManager: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: String = ""
    @Published var isDownloading = false
    @Published var downloadProgress: String = ""
    @Published var errorMessage: String = ""
    @Published var showingErrorAlert = false

    private let sshManager: CitadelSFTPManager
    private let clipboard: RemoteClipboard

    init(sshManager: CitadelSFTPManager, clipboard: RemoteClipboard) {
        self.sshManager = sshManager
        self.clipboard = clipboard
    }

    // MARK: - Create Operations

    func createFolder(name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let folderName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderPath = sshManager.currentPath.hasSuffix("/")
            ? "\(sshManager.currentPath)\(folderName)"
            : "\(sshManager.currentPath)/\(folderName)"

        do {
            try await sshManager.createDirectory(path: folderPath)
            try await sshManager.listFiles(path: sshManager.currentPath)
        } catch {
            print("Failed to create folder: \(error)")
            errorMessage = "Failed to create folder '\(folderName)': \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    func createFile(name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let fileName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let filePath = sshManager.currentPath.hasSuffix("/")
            ? "\(sshManager.currentPath)\(fileName)"
            : "\(sshManager.currentPath)/\(fileName)"

        do {
            // Create an empty temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try Data().write(to: tempURL)

            // Upload the empty file to create it on the remote server
            try await sshManager.uploadFile(localURL: tempURL, to: filePath)

            // Clean up the temporary file
            try? FileManager.default.removeItem(at: tempURL)

            // Refresh the directory listing
            try await sshManager.listFiles(path: sshManager.currentPath)
        } catch {
            print("Failed to create file: \(error)")
            errorMessage = "Failed to create file '\(fileName)': \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    // MARK: - Delete Operation

    func deleteFile(_ file: RemoteFile) async {
        do {
            try await sshManager.deleteFile(path: file.path, isDirectory: file.isDirectory)
            try await sshManager.listFiles(path: sshManager.currentPath)
        } catch {
            print("Failed to delete file: \(error)")
            errorMessage = "Failed to delete '\(file.name)': \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    // MARK: - Rename Operation

    func renameFile(_ file: RemoteFile, newName: String) async {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Build new path
        let pathComponents = file.path.split(separator: "/")
        let parentPath = pathComponents.dropLast().joined(separator: "/")
        let newPath = parentPath.isEmpty ? "/\(trimmedName)" : "/\(parentPath)/\(trimmedName)"

        do {
            try await sshManager.renameFile(from: file.path, to: newPath)
            try await sshManager.listFiles(path: sshManager.currentPath)
        } catch {
            print("Failed to rename file: \(error)")
            errorMessage = "Failed to rename '\(file.name)': \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    // MARK: - Copy/Cut/Paste Operations

    func copyFile(_ file: RemoteFile) {
        clipboard.copy(files: [file], from: sshManager.currentPath)
    }

    func cutFile(_ file: RemoteFile) {
        clipboard.cut(files: [file], from: sshManager.currentPath)
    }

    func pasteFiles() async {
        guard !clipboard.isEmpty else { return }

        do {
            for item in clipboard.items {
                let destinationPath: String

                // Build destination path
                if sshManager.currentPath.hasSuffix("/") {
                    destinationPath = "\(sshManager.currentPath)\(item.file.name)"
                } else {
                    destinationPath = "\(sshManager.currentPath)/\(item.file.name)"
                }

                // Check if pasting in the same directory
                if item.sourcePath == sshManager.currentPath {
                    // Add " copy" suffix to avoid conflicts
                    let nameWithoutExt = (item.file.name as NSString).deletingPathExtension
                    let ext = (item.file.name as NSString).pathExtension
                    let newName = ext.isEmpty ? "\(nameWithoutExt) copy" : "\(nameWithoutExt) copy.\(ext)"
                    let adjustedDestination = sshManager.currentPath.hasSuffix("/")
                        ? "\(sshManager.currentPath)\(newName)"
                        : "\(sshManager.currentPath)/\(newName)"

                    try await sshManager.copyFile(
                        from: item.file.path,
                        to: adjustedDestination,
                        isDirectory: item.file.isDirectory
                    )
                } else {
                    // Different directory - perform copy or move
                    if item.operation == .copy {
                        try await sshManager.copyFile(
                            from: item.file.path,
                            to: destinationPath,
                            isDirectory: item.file.isDirectory
                        )
                    } else {
                        // Cut operation - move the file
                        try await sshManager.moveFile(
                            from: item.file.path,
                            to: destinationPath
                        )
                    }
                }
            }

            // Clear clipboard if it was a cut operation
            if clipboard.isCut {
                clipboard.clear()
            }

            // Refresh the directory listing
            try await sshManager.listFiles(path: sshManager.currentPath)
        } catch {
            print("Failed to paste: \(error)")
            errorMessage = "Failed to paste: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    // MARK: - Upload Operations

    func handleDrop(providers: [NSItemProvider]) {
        Task {
            isUploading = true
            uploadProgress = "Preparing upload..."

            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        guard let url = url else { return }

                        Task { @MainActor in
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
            uploadProgress = "Creating folder: \(itemName)"

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
                errorMessage = "Failed to upload folder '\(itemName)': \(error.localizedDescription)"
                showingErrorAlert = true
            }
        } else {
            // It's a file - upload it
            uploadProgress = "Uploading: \(itemName)"

            do {
                try await sshManager.uploadFile(localURL: localURL, to: remotePath)
            } catch {
                errorMessage = "Failed to upload file '\(itemName)': \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }

        // Refresh directory after all uploads complete
        if remoteBasePath == sshManager.currentPath {
            uploadProgress = "Refreshing..."
            try? await sshManager.listFiles(path: sshManager.currentPath)
            isUploading = false
            uploadProgress = ""
        }
    }

    // MARK: - Download Operations

    func downloadFile(_ file: RemoteFile) {
        // Open save panel to choose download location
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = file.name
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false

        if file.isDirectory {
            savePanel.message = "Choose where to save the folder"
            savePanel.prompt = "Download Folder"
        } else {
            savePanel.message = "Choose where to save the file"
            savePanel.prompt = "Download File"
        }

        savePanel.begin { response in
            guard response == .OK, let saveURL = savePanel.url else {
                return
            }

            Task { @MainActor in
                await self.downloadItemRecursively(remoteFile: file, localURL: saveURL)
            }
        }
    }

    private func downloadItemRecursively(remoteFile: RemoteFile, localURL: URL) async {
        isDownloading = true
        downloadProgress = "Downloading: \(remoteFile.name)"

        defer {
            isDownloading = false
            downloadProgress = ""
        }

        let fileManager = FileManager.default

        if remoteFile.isDirectory {
            // Create local directory
            do {
                try fileManager.createDirectory(at: localURL, withIntermediateDirectories: true)
            } catch {
                errorMessage = "Failed to create directory '\(remoteFile.name)': \(error.localizedDescription)"
                showingErrorAlert = true
                return
            }

            // List remote directory contents
            do {
                let originalPath = sshManager.currentPath
                try await sshManager.listFiles(path: remoteFile.path)
                let remoteContents = sshManager.remoteFiles

                // Download each item recursively
                for item in remoteContents {
                    let itemLocalURL = localURL.appendingPathComponent(item.name)
                    await downloadItemRecursively(remoteFile: item, localURL: itemLocalURL)
                }

                // Restore original path
                try await sshManager.listFiles(path: originalPath)
            } catch {
                errorMessage = "Failed to download folder '\(remoteFile.name)': \(error.localizedDescription)"
                showingErrorAlert = true
            }
        } else {
            // Download file
            downloadProgress = "Downloading: \(remoteFile.name)"

            do {
                try await sshManager.downloadFile(remotePath: remoteFile.path, to: localURL)
            } catch {
                errorMessage = "Failed to download file '\(remoteFile.name)': \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}
