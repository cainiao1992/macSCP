//
//  JSONImportViewModel.swift
//  macSCP
//
//  ViewModel for JSON connection import sheet (Phase 6, IMP-04).
//  Mirrors SSHConfigImportViewModel's state machine + duplicate detection +
//  conflict resolution, but operates on Connection directly (no SSH parsing).
//  Reuses ConflictAction + detectDuplicates (Host+User+Port) + ConflictDropdown.
//

import Foundation
import SwiftUI

/// Manages the JSON connection import flow: file selection, JSON decode,
/// entry display, duplicate detection, conflict resolution, and batch save.
@MainActor
@Observable
final class JSONImportViewModel {

    // MARK: - Import State

    /// State machine for the import sheet (mirrors Phase 5 — SC#4).
    enum ImportState: Equatable {
        case idle
        case parsing
        case parsedEmpty
        case parsed
        case error(String)
        case importing
        case done(Int)
    }

    // MARK: - Published State

    var state: ImportState = .idle
    var entries: [JSONImportEntry] = []
    var selectedIds: Set<UUID> = []
    var filePath: String = ""
    var importError: String?
    var importingCount: Int = 0

    // MARK: - Dependencies

    private let connectionRepository: ConnectionRepositoryProtocol
    private let keychainService: KeychainServiceProtocol
    private let existingConnections: [Connection]

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    init(
        connectionRepository: ConnectionRepositoryProtocol,
        keychainService: KeychainServiceProtocol,
        existingConnections: [Connection]
    ) {
        self.connectionRepository = connectionRepository
        self.keychainService = keychainService
        self.existingConnections = existingConnections
    }

    // MARK: - Computed Properties

    var selectedCount: Int {
        selectedIds.count
    }

    var totalCount: Int {
        entries.count
    }

    var hasConflicts: Bool {
        entries.contains(where: \.isDuplicate)
    }

    var effectiveImportCount: Int {
        entries.filter { entry in
            selectedIds.contains(entry.id) &&
            !(entry.isDuplicate && entry.conflictAction == .skip)
        }.count
    }

    var selectAllBinding: Binding<Bool> {
        Binding<Bool>(
            get: { [weak self] in
                guard let self else { return false }
                if self.entries.isEmpty { return false }
                return self.selectedIds.count == self.entries.count
            },
            set: { [weak self] newValue in
                self?.selectAll(newValue)
            }
        )
    }

    // MARK: - File Selection

    func pickFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose macSCP Export File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let documentsDir {
            panel.directoryURL = documentsDir
        }

        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
            Task { await loadFile(at: url) }
        }
    }

    // MARK: - Loading / Decoding

    func loadFile(at url: URL) async {
        state = .parsing
        importError = nil

        do {
            let data = try Data(contentsOf: url)
            let file = try ConnectionExportCodec.decoder().decode(
                ConnectionExportFile.self,
                from: data
            )

            var parsedEntries = file.connections.map { connection in
                JSONImportEntry(connection: connection)
            }
            detectDuplicates(in: &parsedEntries)

            entries = parsedEntries
            selectedIds = Set(parsedEntries.map(\.id))

            if parsedEntries.isEmpty {
                state = .parsedEmpty
                postAccessibilityAnnouncement("No importable entries found")
            } else {
                state = .parsed
                postAccessibilityAnnouncement("Found \(parsedEntries.count) connections to import")
            }
        } catch {
            let appError = AppError.from(error)
            state = .error(appError.errorDescription ?? "Unknown error")
            postAccessibilityAnnouncement("Failed to load file: \(appError.errorDescription ?? "unknown error")")
        }
    }

    // MARK: - Selection

    func toggleSelection(for entry: JSONImportEntry) {
        if selectedIds.contains(entry.id) {
            selectedIds.remove(entry.id)
        } else {
            selectedIds.insert(entry.id)
        }
    }

    func selectAll(_ selected: Bool) {
        if selected {
            selectedIds = Set(entries.map(\.id))
        } else {
            selectedIds.removeAll()
        }
    }

    // MARK: - Conflict Resolution

    func updateConflictAction(for entryId: UUID, action: ConflictAction) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].conflictAction = action
    }

    // MARK: - Import

    /// Batch-saves selected connections. Security (SC#3, T-6-03):
    /// every imported connection is forced `savePassword = false` and NO
    /// Keychain write is performed — `connectionRepository.save/update` only.
    func importSelected() async {
        importingCount = effectiveImportCount
        state = .importing
        importError = nil

        let entriesToImport = entries.filter { entry in
            selectedIds.contains(entry.id) &&
            !(entry.isDuplicate && entry.conflictAction == .skip)
        }

        var importedCount = 0
        var importedIds = Set<UUID>()
        var failedEntries: [(JSONImportEntry, Error)] = []

        for entry in entriesToImport {
            do {
                // SC#3: force savePassword=false before any persistence.
                var conn = entry.connection
                conn.savePassword = false
                // CR-01: clear orphaned folderId — the imported folderId
                // references a folder UUID from the source machine that does
                // not exist on this machine, making the connection invisible
                // in every sidebar section. v1 import lands connections in
                // "All Connections" (folderId=nil); folder-aware import is
                // deferred to v2+.
                conn.folderId = nil

                if entry.isDuplicate && entry.conflictAction == .overwrite {
                    // Overwrite: apply imported config fields onto the matched
                    // existing connection, preserving its immutable id and
                    // organizational metadata (createdAt/isFavorite/lastUsedAt).
                    // `existing.id` is `let`, so we mutate a copy's `var` fields.
                    // No Keychain write (T-6-03).
                    if let existing = findExistingConnection(for: entry) {
                        // WR-01: clean up stale Keychain credentials on
                        // overwrite (mirrors Phase 5 SSHConfigImportViewModel).
                        // SC#3 requires re-entering the password — a stale
                        // Keychain entry would silently bypass the prompt.
                        // T-6-03 allows deletes (prohibits writes).
                        if existing.connectionType == .s3 {
                            try? keychainService.deleteS3Credentials(for: existing.id)
                        } else {
                            try? keychainService.deletePassword(for: existing.id)
                        }
                        var updated = existing
                        updated.name = conn.name
                        updated.host = conn.host
                        updated.port = conn.port
                        updated.username = conn.username
                        updated.authMethod = conn.authMethod
                        updated.privateKeyPath = conn.privateKeyPath
                        updated.connectionType = conn.connectionType
                        updated.s3Region = conn.s3Region
                        updated.s3Bucket = conn.s3Bucket
                        updated.s3Endpoint = conn.s3Endpoint
                        updated.description = conn.description
                        updated.tags = conn.tags
                        updated.iconName = conn.iconName
                        // CR-01: preserve existing connection's folderId —
                        // do NOT overwrite with the imported (orphaned) value.
                        // `updated` was initialized from `existing`, so
                        // updated.folderId already holds the valid local id.
                        updated.savePassword = false
                        updated.updatedAt = Date()
                        try await connectionRepository.update(updated)
                    } else {
                        // No match found (shouldn't happen for a flagged
                        // duplicate, but guard regardless) — save as new.
                        try await connectionRepository.save(conn)
                    }
                } else {
                    // New connection — save directly (no Keychain write, T-6-03).
                    try await connectionRepository.save(conn)
                }
                importedIds.insert(entry.id)
                importedCount += 1
            } catch {
                failedEntries.append((entry, error))
            }
        }

        if failedEntries.isEmpty {
            state = .done(importedCount)
            postAccessibilityAnnouncement("Successfully imported \(importedCount) connections")
        } else {
            // Partial failure — remove successfully imported entries to prevent
            // duplicates on retry.
            if !importedIds.isEmpty {
                entries.removeAll { importedIds.contains($0.id) }
                selectedIds.subtract(importedIds)
            }
            importError = "Failed to import \(failedEntries.count) connection(s)"
            state = .parsed
        }
    }

    // MARK: - Conflict Detection
    //
    // Delegates the generic host+username+port match to the shared
    // `ConnectionConflictDetector` (W-1). JSON entries carry the resolved
    // Connection fields directly, so no alias/nil-user adaptation is needed
    // here — values are forwarded as-is.
    private func detectDuplicates(in entries: inout [JSONImportEntry]) {
        for i in entries.indices {
            let connection = entries[i].connection
            entries[i].isDuplicate = ConnectionConflictDetector.findExisting(
                host: connection.host,
                username: connection.username,
                port: connection.port,
                in: existingConnections
            ) != nil
        }
    }

    private func findExistingConnection(for entry: JSONImportEntry) -> Connection? {
        let connection = entry.connection
        return ConnectionConflictDetector.findExisting(
            host: connection.host,
            username: connection.username,
            port: connection.port,
            in: existingConnections
        )
    }

    // MARK: - Accessibility

    private func postAccessibilityAnnouncement(_ message: String) {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }
        NSAccessibility.post(
            element: window,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
    }
}

// MARK: - Import Entry

/// Adapter wrapping a decoded Connection with per-row import metadata
/// (mirrors SSHConfigEntry's role in Phase 5, but operates on Connection).
/// `id` derives from `connection.id` to support overwrite-by-key.
struct JSONImportEntry: Identifiable, Hashable, Sendable {
    var connection: Connection
    var isDuplicate: Bool = false
    var conflictAction: ConflictAction = .skip

    var id: UUID { connection.id }
}
