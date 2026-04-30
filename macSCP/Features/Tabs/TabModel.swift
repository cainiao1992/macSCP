//
//  TabModel.swift
//  macSCP
//
//  Data model representing a single browser tab
//

import Foundation

struct TabModel: Identifiable, Hashable {
    let id: UUID
    let connectionId: UUID
    let connectionName: String
    let connectionType: ConnectionType
    let host: String
    let password: String
    let viewModel: FileBrowserViewModel

    // MARK: - Computed Properties

    var title: String { connectionName }

    var icon: String {
        switch connectionType {
        case .sftp: return "desktopcomputer"
        case .s3: return "externaldrive"
        }
    }

    // MARK: - Hashable (hash on id only)

    static func == (lhs: TabModel, rhs: TabModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
