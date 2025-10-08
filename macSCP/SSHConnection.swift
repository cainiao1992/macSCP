//
//  SSHConnection.swift
//  macSCP
//
//  SSH Connection Model
//

import Foundation
import SwiftData

@Model
class SSHConnection {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var timestamp: Date

    var folder: ConnectionFolder?

    init(name: String, host: String, port: Int = 22, username: String, folder: ConnectionFolder? = nil) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.timestamp = Date()
        self.folder = folder
    }
}
