//
//  DeleteFolderAlertModifier.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import SwiftUI

struct DeleteFolderAlertModifier: ViewModifier {
    @Binding var folderToDelete: ConnectionFolder?
    let onKeepConnections: (ConnectionFolder) -> Void
    let onDeleteAll: (ConnectionFolder) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Delete Folder",
                isPresented: Binding(
                    get: { folderToDelete != nil },
                    set: { if !$0 { folderToDelete = nil } }
                ),
                presenting: folderToDelete
            ) { folder in
                Button("Cancel", role: .cancel) {
                    folderToDelete = nil
                }

                if !folder.connections.isEmpty {
                    Button("Keep Connections", role: .none) {
                        onKeepConnections(folder)
                    }
                    Button("Delete All", role: .destructive) {
                        onDeleteAll(folder)
                    }
                } else {
                    Button("Delete Folder", role: .destructive) {
                        onKeepConnections(folder)
                    }
                }
            } message: { folder in
                if folder.connections.isEmpty {
                    Text("Are you sure you want to delete '\(folder.name)'?")
                } else {
                    Text("The folder '\(folder.name)' contains \(folder.connections.count) connection(s). Do you want to keep the connections or delete everything?")
                }
            }
    }
}

extension View {
    func deleteFolderAlert(
        folder: Binding<ConnectionFolder?>,
        onKeepConnections: @escaping (ConnectionFolder) -> Void,
        onDeleteAll: @escaping (ConnectionFolder) -> Void
    ) -> some View {
        modifier(DeleteFolderAlertModifier(
            folderToDelete: folder,
            onKeepConnections: onKeepConnections,
            onDeleteAll: onDeleteAll
        ))
    }
}
