//
//  RemoteFile.swift
//  macSCP
//
//  Remote File Model
//

import Foundation

struct RemoteFile: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let permissions: String
    let modificationDate: Date?

    init(id: UUID = UUID(), name: String, path: String, isDirectory: Bool, size: Int64, permissions: String, modificationDate: Date?) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.permissions = permissions
        self.modificationDate = modificationDate
    }

    var displaySize: String {
        if isDirectory {
            return "Directory"
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
