//
//  SSHConnection.swift
//  macSCP
//
//  SSH Connection Model
//

import Foundation
import SwiftData

enum AuthenticationType: String, Codable {
    case password
    case key
}

@Model
class SSHConnection {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var timestamp: Date
    var authenticationType: AuthenticationType?
    var privateKeyPath: String? // Path to the SSH key file
    var savePassword: Bool?

    var folder: ConnectionFolder?

    // Computed property for backwards compatibility
    var authType: AuthenticationType {
        get { authenticationType ?? .password }
        set { authenticationType = newValue }
    }

    var shouldSavePassword: Bool {
        get { savePassword ?? false }
        set { savePassword = newValue }
    }

    init(name: String, host: String, port: Int = 22, username: String, authenticationType: AuthenticationType = .password, privateKeyPath: String? = nil, savePassword: Bool = false, folder: ConnectionFolder? = nil) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authenticationType = authenticationType
        self.privateKeyPath = privateKeyPath
        self.savePassword = savePassword
        self.timestamp = Date()
        self.folder = folder
    }
}
