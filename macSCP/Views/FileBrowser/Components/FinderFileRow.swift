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

                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 12) {
                    if !file.isDirectory {
                        Text(file.displaySize)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Text(file.permissions)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .monospaced()

                    if file.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
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
                    Text("Open")
                }
                .keyboardShortcut(.return, modifiers: [])

                Button(action: {
                    onDownload(file)
                }) {
                    Text("Download Folder")
                }

                Divider()
            } else {
                Button(action: {
                    onEdit(file)
                }) {
                    Text("Edit in Text Editor")
                }

                Button(action: {
                    onDownload(file)
                }) {
                    Text("Download to Mac")
                }
                Divider()
            }

            Button(action: {
                onCopy(file)
            }) {
                Text("Copy")
            }
            .keyboardShortcut("c", modifiers: .command)

            Button(action: {
                onCut(file)
            }) {
                Text("Cut")
            }
            .keyboardShortcut("x", modifiers: .command)

            Button(action: {
                onPaste()
            }) {
                Text("Paste Here")
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(clipboard.isEmpty)

            Divider()

            Button(action: {
                onRename(file)
            }) {
                Text("Rename")
            }

            Button(role: .destructive, action: {
                onDelete(file)
            }) {
                Text("Delete")
            }
            .keyboardShortcut(.delete, modifiers: [])

            Divider()

            Button(action: {
                onInfo(file)
            }) {
                Text("Get Info")
            }
            .keyboardShortcut("i", modifiers: .command)
        }
    }
}
