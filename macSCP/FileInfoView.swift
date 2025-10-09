//
//  FileInfoView.swift
//  macSCP
//
//  File/Folder information window
//

import SwiftUI

struct FileInfoView: View {
    let file: RemoteFile

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and name
            VStack(spacing: 16) {
                FileIcon(file: file, size: 64)

                Text(file.name)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Information section
            Form {
                Section("General") {
                    InfoRow(label: "Name", value: file.name)
                    InfoRow(label: "Kind", value: file.isDirectory ? "Folder" : "File")
                    InfoRow(label: "Path", value: file.path)
                }

                Section("Details") {
                    if !file.isDirectory {
                        InfoRow(label: "Size", value: file.displaySize)
                        InfoRow(label: "Size (bytes)", value: "\(file.size)")
                    }
                    InfoRow(label: "Permissions", value: file.permissions)
                    if let date = file.modificationDate {
                        InfoRow(label: "Modified", value: date.formatted(date: .long, time: .standard))
                    }
                }

                if let ext = fileExtension {
                    Section("File Info") {
                        InfoRow(label: "Extension", value: ext)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 400, height: 500)
    }

    private var fileExtension: String? {
        guard !file.isDirectory else { return nil }
        let ext = (file.name as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// Container view that retrieves file info from UserDefaults
struct FileInfoContainerView: View {
    let infoId: String
    @State private var file: RemoteFile?

    var body: some View {
        Group {
            if let file = file {
                FileInfoView(file: file)
            } else {
                VStack {
                    ProgressView()
                    Text("Loading file info...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(width: 400, height: 500)
            }
        }
        .onAppear {
            loadFileInfo()
        }
    }

    private func loadFileInfo() {
        guard let fileData = UserDefaults.standard.data(forKey: "pendingFileInfo_\(infoId)"),
              let decodedFile = try? JSONDecoder().decode(RemoteFile.self, from: fileData) else {
            return
        }

        file = decodedFile

        // Clean up
        UserDefaults.standard.removeObject(forKey: "pendingFileInfo_\(infoId)")
    }
}

#Preview {
    FileInfoView(file: RemoteFile(
        name: "example.txt",
        path: "/home/user/example.txt",
        isDirectory: false,
        size: 1024,
        permissions: "-rw-r--r--",
        modificationDate: Date()
    ))
}
