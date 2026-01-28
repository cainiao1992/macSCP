//
//  NewFolderView.swift
//  macSCP
//
//  Sheet for creating a new folder
//

import SwiftUI

struct NewFolderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var folderName: String
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Folder")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Create a folder to organize your connections")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Folder Name")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("e.g., Production Servers", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !folderName.isEmptyOrWhitespace {
                            onCreate()
                        }
                    }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Folder") {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(folderName.isEmptyOrWhitespace)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .frame(width: 450, height: 260)
    }
}
