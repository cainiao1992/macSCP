//
//  EmptyFolderView.swift
//  macSCP
//
//  Empty state view for folders with no connections
//

import SwiftUI

struct EmptyFolderView: View {
    let onAddConnection: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "network.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No connections in this folder")
                .foregroundColor(.secondary)
                .padding()
            Button("Add Connection") {
                onAddConnection()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
}
