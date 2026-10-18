//
//  SSHConfigImportViewModel.swift
//  macSCP
//
//  ViewModel for SSH config import sheet — state machine, parsing, batch save
//

import Foundation
import SwiftUI

/// Manages the SSH config import flow: file selection, parsing, entry display,
/// duplicate detection, conflict resolution, and batch connection creation.
@MainActor
@Observable
final class SSHConfigImportViewModel {

    // MARK: - Import State

    /// State machine for the import sheet.
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
    var entries: [SSHConfigEntry] = []
    var selectedIds: Set<UUID> = []
    var filePath: String = ""
    var wildcardCount: Int = 0
    var includeWarnings: [String] = []
    var includeWarningPopoverPresented: Bool = false
    var importError: String?
    var importingCount: Int = 0

    // MARK: - Dependencies

    private let parser: SSHConfigParser
    private let connectionRepository: ConnectionRepositoryProtocol
    private let keychainService: KeychainServiceProtocol
    private let existingConnections: [Connection]

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?

    // MARK: - Initialization

    init(
        parser: SSHConfigParser,
        connectionRepository: ConnectionRepositoryProtocol,
        keychainService: KeychainServiceProtocol,
        existingConnections: [Connection]
    ) {
        self.parser = parser
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
        panel.title = "Choose SSH Config File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        let sshDir = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh")
        if FileManager.default.fileExists(atPath: sshDir) {
            panel.directoryURL = URL(fileURLWithPath: sshDir)
        }

        if panel.runModal() == .OK, let url = panel.url {
            filePath = url.path
            Task { await parseFile(at: url) }
        }
    }

    // MARK: - Parsing

    func parseFile(at url: URL) async {
        state = .parsing
        importError = nil

        do {
            let result = try parser.parse(fileURL: url)
            wildcardCount = result.wildcardCount
            includeWarnings = result.includeWarnings

            var parsedEntries = result.entries
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
            postAccessibilityAnnouncement("Failed to parse config: \(appError.errorDescription ?? "unknown error")")
        }
    }

    // MARK: - Selection

    func toggleSelection(for entry: SSHConfigEntry) {
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
        var failedEntries: [(SSHConfigEntry, Error)] = []

        for entry in entriesToImport {
            do {
                if entry.isDuplicate && entry.conflictAction == .overwrite {
                    // Find and update existing connection
                    if let existing = findExistingConnection(for: entry) {
                        // Clean up stale credentials before overwriting
                        if existing.connectionType == .s3 {
                            try? keychainService.deleteS3Credentials(for: existing.id)
                        } else {
                            try? keychainService.deletePassword(for: existing.id)
                        }

                        var updated = existing
                        updated.host = entry.hostName ?? entry.host
                        updated.port = entry.port
                        updated.username = entry.user ?? ""
                        updated.privateKeyPath = entry.identityFile
                        updated.authMethod = entry.identityFile != nil ? .privateKey : .password
                        updated.updatedAt = Date()
                        try await connectionRepository.update(updated)
                    }
                } else {
                    // Create new connection
                    let connection = connectionFromEntry(entry)
                    try await connectionRepository.save(connection)
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
            // Partial failure — remove successfully imported entries to prevent duplicates on retry
            if !importedIds.isEmpty {
                entries.removeAll { importedIds.contains($0.id) }
                selectedIds.subtract(importedIds)
            }
            importError = "Failed to import \(failedEntries.count) connection(s)"
            state = .parsed
        }
    }

    // MARK: - Mapping

    func connectionFromEntry(_ entry: SSHConfigEntry) -> Connection {
        Connection(
            name: entry.host,
            host: entry.hostName ?? entry.host,
            port: entry.port,
            username: entry.user ?? "",
            authMethod: entry.identityFile != nil ? .privateKey : .password,
            privateKeyPath: entry.identityFile,
            savePassword: false,
            tags: [],
            iconName: "server.rack",
            folderId: nil,
            connectionType: .sftp
        )
    }

    // MARK: - Popover

    func toggleIncludeWarningPopover() {
        includeWarningPopoverPresented.toggle()
    }

    // MARK: - Conflict Detection
    //
    // Delegates the generic host+username+port match to the shared
    // `ConnectionConflictDetector` (W-1). The SSH-specific adaptation stays
    // here: resolve the alias (`HostName ?? Host`) and the nil-user fallback
    // (default `""`) before handing already-resolved values to the helper.

    private func detectDuplicates(in entries: inout [SSHConfigEntry]) {
        for i in entries.indices {
            let entry = entries[i]
            let resolvedHost = entry.hostName ?? entry.host
            entries[i].isDuplicate = ConnectionConflictDetector.findExisting(
                host: resolvedHost,
                username: entry.user ?? "",
                port: entry.port,
                in: existingConnections
            ) != nil
        }
    }

    private func findExistingConnection(for entry: SSHConfigEntry) -> Connection? {
        let resolvedHost = entry.hostName ?? entry.host
        return ConnectionConflictDetector.findExisting(
            host: resolvedHost,
            username: entry.user ?? "",
            port: entry.port,
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
