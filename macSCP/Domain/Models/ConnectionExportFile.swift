//
//  ConnectionExportFile.swift
//  macSCP
//
//  Versioned Codable wrapper for JSON connection export/import (Phase 6).
//  Security: Connection has no password/s3Secret field, so synthesized
//  Codable cannot leak credentials. The codec is the single encode/decode
//  entry point shared by export (EXP-01/02) and import (IMP-04).
//

import Foundation

/// Top-level export envelope. Wraps `[Connection]` + `[Folder]` with a version
/// field for forward-compatible format evolution and an ISO-8601 timestamp.
///
/// Uses fully synthesized `Codable` (no custom key mapping) — this is the
/// structural guarantee that injected JSON keys (e.g. a hand-edited
/// `"password"`) are silently ignored on decode (T-6-02).
struct ConnectionExportFile: Codable, Sendable {
    /// Format version. Bump on any breaking schema change.
    let version: Int
    /// When the file was exported (ISO-8601 in JSON, see `ConnectionExportCodec`).
    let exportedAt: Date
    /// App version that produced the export (read from `CFBundleShortVersionString`).
    let appVersion: String
    /// Exported connection configurations. Secret-free by construction
    /// (Connection has no password/s3Secret stored property).
    let connections: [Connection]
    /// Exported folder definitions (SC#1 "文件夹归属").
    let folders: [Folder]

    /// Current export format version.
    static let currentVersion = 1
}

/// Isolates JSON encode/decode so it is unit-testable independent of the
/// NSSavePanel/NSOpenPanel UI flows (Pitfall 5). Encoder and decoder share the
/// same `.iso8601` date strategy so round-trips are stable (Pitfall 1).
enum ConnectionExportCodec {
    /// Pretty-printed, sorted-key, ISO-8601-date encoder for diffable backups.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// ISO-8601-date decoder matching the encoder. Unknown JSON keys are
    /// ignored by synthesized Codable (T-6-02 tampering mitigation).
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
