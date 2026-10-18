//
//  SSHConfigEntry.swift
//  macSCP
//
//  Domain model for a parsed SSH config entry used during import
//

import Foundation

/// A single parsed entry from an SSH config file.
///
/// The parser creates entries with the raw parsed values. The import ViewModel
/// then sets `isDuplicate` and `conflictAction` by comparing against existing connections.
struct SSHConfigEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var host: String
    var hostName: String?
    var port: Int
    var user: String?
    var identityFile: String?
    var isDuplicate: Bool
    var conflictAction: ConflictAction

    init(
        id: UUID = UUID(),
        host: String,
        hostName: String? = nil,
        port: Int = 22,
        user: String? = nil,
        identityFile: String? = nil,
        isDuplicate: Bool = false,
        conflictAction: ConflictAction = .skip
    ) {
        self.id = id
        self.host = host
        self.hostName = hostName
        self.port = port
        self.user = user
        self.identityFile = identityFile
        self.isDuplicate = isDuplicate
        self.conflictAction = conflictAction
    }
}
