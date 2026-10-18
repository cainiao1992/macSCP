//
//  ConnectionConflictDetector.swift
//  macSCP
//
//  Shared host+username+port conflict detection used by both import flows
//  (SSHConfigImportViewModel and JSONImportViewModel). Extracted from the
//  duplicated detectDuplicates/findExistingConnection predicates (W-1).
//
//  Each ViewModel keeps its own data-structure adaptation (SSH alias → hostName
//  resolution stays in SSHConfigImportViewModel; JSON passes Connection fields
//  directly) and delegates only the generic match predicate to this helper.
//

import Foundation

/// Caseless namespace for the shared connection-conflict predicate.
///
/// A connection is considered a duplicate of an existing one when all three
/// keys match: **host** (case-insensitive), **username** (exact),
/// **port** (exact). This mirrors the original algorithm that lived inline in
/// both import ViewModels.
enum ConnectionConflictDetector {

    // MARK: - Conflict Detection

    /// Finds the first existing connection matching `host` + `username` + `port`.
    ///
    /// - Host comparison is case-insensitive (e.g. `Example.COM` matches `example.com`).
    /// - Username and port are compared exactly.
    ///
    /// - Parameters:
    ///   - host: The resolved host (SSH callers resolve `HostName ?? Host` first).
    ///   - username: The resolved username (SSH callers fall back to `""`).
    ///   - port: The connection port.
    ///   - connections: The existing connections to search.
    /// - Returns: The first matching connection, or `nil` when no conflict exists.
    static func findExisting(
        host: String,
        username: String,
        port: Int,
        in connections: [Connection]
    ) -> Connection? {
        connections.first { existing in
            existing.host.caseInsensitiveCompare(host) == .orderedSame &&
            existing.username == username &&
            existing.port == port
        }
    }
}
