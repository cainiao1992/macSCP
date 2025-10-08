//
//  RemoteFile.swift
//  macSCP
//
//  Remote File Model
//

import Foundation

struct RemoteFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let permissions: String
    let modificationDate: Date?

    var displaySize: String {
        if isDirectory {
            return "Directory"
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
