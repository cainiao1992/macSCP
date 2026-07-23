//
//  JSONImportSheet.swift
//  macSCP
//
//  Import sheet view for JSON connection files (Phase 6, IMP-04).
//  Mirrors SSHConfigImportSheet's structure (SC#4): 7-state content area,
//  Table with checkboxes, conditional Conflict column reusing ConflictDropdown.
//

import SwiftUI

/// The main import sheet for JSON connection files. Mirrors Phase 5's
/// SSHConfigImportSheet structure, reusing ConflictDropdown verbatim (SC#4).
struct JSONImportSheet: View {
    @Bindable var viewModel: JSONImportViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footerSection
        }
        .frame(
            minWidth: 720,
            idealWidth: 720,
            minHeight: 560,
            idealHeight: 560,
            alignment: .center
        )
        .fixedSize()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: UIConstants.spacing) {
            Text("Import Connections")
                .font(.headline)
            Spacer()
            if !viewModel.filePath.isEmpty {
                Text(viewModel.filePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Browse...") {
                viewModel.pickFile()
            }
            .buttonStyle(.bordered)
            .fixedSize()
        }
        .padding(.horizontal, UIConstants.spacing)
        .padding(.vertical, 12)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.state {
        case .idle:
            idleView
        case .parsing:
            parsingView
        case .parsedEmpty:
            parsedEmptyView
        case .parsed:
            parsedTableView
        case .error(let errorMessage):
            errorView(errorMessage)
        case .importing:
            importingView
        case .done(let count):
            doneView(count)
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: UIConstants.spacing) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Choose a JSON export file to import connections")
                .foregroundStyle(.secondary)
            Button("Choose File...") {
                viewModel.pickFile()
            }
            .buttonStyle(.bordered)
        }
    }

    private var parsingView: some View {
        VStack(spacing: UIConstants.spacing) {
            ProgressView()
                .controlSize(.large)
            Text("Loading connections...")
                .foregroundStyle(.secondary)
        }
    }

    private var parsedEmptyView: some View {
        EmptyStateView(
            icon: "tray.and.arrow.down",
            title: "No Connections Found",
            message: "The selected file contains no connections to import.",
            actionTitle: "Choose Different File"
        ) {
            viewModel.pickFile()
        }
    }

    private var parsedTableView: some View {
        VStack(spacing: 0) {
            if let importError = viewModel.importError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal, UIConstants.spacing)
                .padding(.vertical, UIConstants.smallSpacing)
            }

            entriesTable
        }
    }

    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: UIConstants.spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text("Failed to Load File")
                .font(.headline)
            Text(errorMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: UIConstants.smallSpacing) {
                Button("Try Again") {
                    viewModel.pickFile()
                }
                .buttonStyle(.bordered)

                Button("Cancel") {
                    viewModel.onDismiss?()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var importingView: some View {
        VStack(spacing: UIConstants.spacing) {
            ProgressView()
                .controlSize(.large)
            Text("Importing \(viewModel.importingCount) connections...")
                .foregroundStyle(.secondary)
        }
    }

    private func doneView(_ count: Int) -> some View {
        VStack(spacing: UIConstants.spacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Imported \(count) connections successfully")
                .font(.headline)
            Button("Done") {
                viewModel.onDismiss?()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Entries Table

    @ViewBuilder
    private var entriesTable: some View {
        if viewModel.hasConflicts {
            entriesTableWithConflict
        } else {
            entriesTableWithoutConflict
        }
    }

    private var entriesTableWithoutConflict: some View {
        Table(viewModel.entries, selection: Binding(
            get: { viewModel.selectedIds },
            set: { newSelection in
                viewModel.selectedIds = newSelection
            }
        )) {
            TableColumn("") { entry in
                Toggle("", isOn: selectionBinding(for: entry))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(isInteractionDisabled)
            }
            .width(32)

            TableColumn("Name") { entry in
                nameCell(for: entry)
            }

            TableColumn("Host") { entry in
                hostCell(for: entry)
            }

            TableColumn("Port") { entry in
                portCell(for: entry)
            }
            .width(50)

            TableColumn("User") { entry in
                userCell(for: entry)
            }
            .width(80)

            TableColumn("Type") { entry in
                typeCell(for: entry)
            }
            .width(60)
        }
    }

    private var entriesTableWithConflict: some View {
        Table(viewModel.entries, selection: Binding(
            get: { viewModel.selectedIds },
            set: { newSelection in
                viewModel.selectedIds = newSelection
            }
        )) {
            TableColumn("") { entry in
                Toggle("", isOn: selectionBinding(for: entry))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(isInteractionDisabled)
            }
            .width(32)

            TableColumn("Name") { entry in
                nameCell(for: entry)
            }

            TableColumn("Host") { entry in
                hostCell(for: entry)
            }

            TableColumn("Port") { entry in
                portCell(for: entry)
            }
            .width(50)

            TableColumn("User") { entry in
                userCell(for: entry)
            }
            .width(80)

            TableColumn("Type") { entry in
                typeCell(for: entry)
            }
            .width(60)

            TableColumn("Conflict") { entry in
                if entry.isDuplicate {
                    ConflictDropdown(
                        entryId: entry.id,
                        action: Binding(
                            get: { entry.conflictAction },
                            set: { viewModel.updateConflictAction(for: entry.id, action: $0) }
                        )
                    )
                    .disabled(isInteractionDisabled)
                    .accessibilityLabel("Conflict action for \(entry.connection.name)")
                    .accessibilityHint("Choose Skip to keep existing connection, or Overwrite to replace it")
                }
            }
            .width(100)
        }
    }

    // MARK: - Table Cell Views

    private func selectionBinding(for entry: JSONImportEntry) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedIds.contains(entry.id) },
            set: { isOn in
                if isOn {
                    viewModel.selectedIds.insert(entry.id)
                } else {
                    viewModel.selectedIds.remove(entry.id)
                }
            }
        )
    }

    private func nameCell(for entry: JSONImportEntry) -> some View {
        HStack(spacing: 4) {
            if entry.isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Text(entry.connection.name)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel(for: entry))
        .accessibilityValue(viewModel.selectedIds.contains(entry.id) ? "Selected" : "Not selected")
        .accessibilityHint("Toggle to include or exclude this connection from import")
    }

    private func hostCell(for entry: JSONImportEntry) -> some View {
        Text(entry.connection.host)
            .lineLimit(1)
    }

    private func portCell(for entry: JSONImportEntry) -> some View {
        Text("\(entry.connection.port)")
            .monospacedDigit()
    }

    private func userCell(for entry: JSONImportEntry) -> some View {
        Text(entry.connection.username)
            .foregroundStyle(entry.connection.username.isEmpty ? .tertiary : .primary)
    }

    private func typeCell(for entry: JSONImportEntry) -> some View {
        Text(entry.connection.connectionType == .s3 ? "S3" : "SFTP")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: UIConstants.spacing) {
            footerStatusText
            Spacer()
            Toggle("Select All", isOn: viewModel.selectAllBinding)
                .toggleStyle(.checkbox)
                .disabled(viewModel.entries.isEmpty || isInteractionDisabled)
                .accessibilityLabel("Select all entries")
                .accessibilityHint("Toggle to select or deselect all importable connections")

            Button("Cancel") {
                viewModel.onDismiss?()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.bordered)
            .fixedSize()

            Button("Import Selected") {
                Task { await viewModel.importSelected() }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.effectiveImportCount == 0 || isInteractionDisabled)
            .accessibilityValue("\(viewModel.effectiveImportCount) connections will be imported")
            .fixedSize()
        }
        .padding(.horizontal, UIConstants.spacing)
        .padding(.vertical, 12)
    }

    private var footerStatusText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(viewModel.selectedCount) of \(viewModel.totalCount) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.effectiveImportCount == 0 && viewModel.selectedCount > 0 && viewModel.hasConflicts {
                Text("No new connections to import")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.selectedCount) of \(viewModel.totalCount) selected")
    }

    // MARK: - Accessibility

    private func accessibilityRowLabel(for entry: JSONImportEntry) -> String {
        let typeText = entry.connection.connectionType == .s3 ? "S3" : "SFTP"
        if entry.isDuplicate {
            return "\(entry.connection.name), duplicate detected, conflict action: \(entry.conflictAction.rawValue), host \(entry.connection.host), port \(entry.connection.port), user \(entry.connection.username), type \(typeText)"
        }
        return "\(entry.connection.name), host \(entry.connection.host), port \(entry.connection.port), user \(entry.connection.username), type \(typeText)"
    }

    // MARK: - Helpers

    private var isInteractionDisabled: Bool {
        switch viewModel.state {
        case .importing, .done:
            return true
        default:
            return false
        }
    }
}
