//
//  FinderFileRow.swift
//  macSCP
//
//  File row component for Finder-style browser
//

import SwiftUI

struct FinderFileRow: View {
    let file: RemoteFile
    @Binding var selectedFileId: RemoteFile.ID?
    @Binding var selectedFile: RemoteFile?
    @ObservedObject var clipboard: RemoteClipboard
    let onNavigate: (String) -> Void
    let onEdit: (RemoteFile) -> Void
    let onDownload: (RemoteFile) -> Void
    let onCopy: (RemoteFile) -> Void
    let onCut: (RemoteFile) -> Void
    let onPaste: () -> Void
    let onRename: (RemoteFile) -> Void
    let onDelete: (RemoteFile) -> Void
    let onInfo: (RemoteFile) -> Void

    var body: some View {
        Button(action: {
            if file.isDirectory {
                onNavigate(file.path)
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
                    onNavigate(file.path)
                }) {
                    Label("Open", systemImage: "folder.fill")
                }

                Button(action: {
                    onDownload(file)
                }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }

                Divider()
            } else {
                Button(action: {
                    onEdit(file)
                }) {
                    Label("Edit", systemImage: "pencil.line")
                }

                Button(action: {
                    onDownload(file)
                }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }
                Divider()
            }

            Button(action: {
                onCopy(file)
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(action: {
                onCut(file)
            }) {
                Label("Cut", systemImage: "scissors")
            }

            Button(action: {
                onPaste()
            }) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .disabled(clipboard.isEmpty)

            Divider()

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

            Divider()

            Button(action: {
                onInfo(file)
            }) {
                Label("Get Info", systemImage: "info.circle")
            }
        }
    }
}
