//
//  FolderRowView.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import SwiftUI

struct FolderRowView: View {
    let folder: ConnectionFolder
    let onDelete: () -> Void
    
    var body: some View {
        NavigationLink(value: SidebarSelection.folder(folder)) {
            HStack {
                Label(folder.name, systemImage: "folder.fill")
                Spacer()
                CountBadge(count: folder.connections.count)
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }
}
