//
//  ConflictDropdown.swift
//  macSCP
//
//  Per-row Skip/Overwrite picker for duplicate SSH config entries
//

import SwiftUI

/// A compact Picker displaying Skip/Overwrite options for conflict resolution.
/// Stateless — receives a Binding to the entry's conflict action.
struct ConflictDropdown: View {
    let entryId: UUID
    @Binding var action: ConflictAction

    var body: some View {
        Picker("", selection: $action) {
            Text("Skip").tag(ConflictAction.skip)
            Text("Overwrite").tag(ConflictAction.overwrite)
        }
        .pickerStyle(.menu)
        .frame(width: 92)
    }
}
