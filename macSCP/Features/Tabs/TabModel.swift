//
//  TabModel.swift
//  macSCP
//
//  Data model representing a single browser tab (file browser or terminal)
//

import Foundation

/// Discriminator for the kind of content a tab hosts.
enum TabKind: Hashable, Sendable {
    case fileBrowser
    case terminal
}

/// Content carried by a tab — associates the kind with its owning ViewModel.
@MainActor
enum TabContent {
    case fileBrowser(FileBrowserViewModel)
    case terminal(TerminalViewModel)
}

struct TabModel: Identifiable, Hashable {
    let id: UUID
    let connectionId: UUID
    let connectionName: String
    let connectionType: ConnectionType
    let host: String
    let password: String
    let kind: TabKind
    let content: TabContent

    // MARK: - Computed Properties

    var title: String { connectionName }

    var icon: String {
        switch kind {
        case .fileBrowser:
            switch connectionType {
            case .sftp: return "desktopcomputer"
            case .s3: return "externaldrive"
            }
        case .terminal:
            return "terminal"
        }
    }

    /// Convenience accessor for the file-browser ViewModel when this tab hosts one.
    var fileBrowserViewModel: FileBrowserViewModel? {
        if case .fileBrowser(let viewModel) = content { return viewModel }
        return nil
    }

    /// Convenience accessor for the terminal ViewModel when this tab hosts one.
    var terminalViewModel: TerminalViewModel? {
        if case .terminal(let viewModel) = content { return viewModel }
        return nil
    }

    // MARK: - Hashable (hash on id only)

    static func == (lhs: TabModel, rhs: TabModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
