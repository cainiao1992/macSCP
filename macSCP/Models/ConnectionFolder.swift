//
//  ConnectionFolder.swift
//  macSCP
//
//  Folder for organizing SSH connections
//

import Foundation
import SwiftData

@Model
class ConnectionFolder {
    var id: UUID
    var name: String
    var timestamp: Date

    @Relationship(deleteRule: .cascade, inverse: \SSHConnection.folder)
    var connections: [SSHConnection]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.timestamp = Date()
        self.connections = []
    }
}
