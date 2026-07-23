//
//  ConflictAction.swift
//  macSCP
//
//  Conflict resolution action for SSH config import duplicates
//

import Foundation

/// Resolution action when an imported SSH config entry conflicts with an existing connection.
enum ConflictAction: String, CaseIterable, Sendable {
    /// Skip the duplicate entry (keep existing connection unchanged)
    case skip = "Skip"
    /// Overwrite the existing connection with the imported entry
    case overwrite = "Overwrite"
}
