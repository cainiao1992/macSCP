//
//  NoFolderSelectedView.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import SwiftUI

struct NoFolderSelectedView: View {
    let onCreateFolder: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Folder Selected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create a folder to organize your SSH connections")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onCreateFolder) {
                Label("Create New Folder", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
