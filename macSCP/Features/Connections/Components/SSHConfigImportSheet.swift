//
//  SSHConfigImportSheet.swift
//  macSCP
//
//  Import sheet view for SSH config files — Table with entries, checkboxes, and state machine
//

import SwiftUI

/// The main import sheet displayed when the user initiates SSH config import.
/// Presents a file picker, parsed entries table, and import actions.
struct SSHConfigImportSheet: View {
    @Bindable var viewModel: SSHConfigImportViewModel

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
            Text("Import SSH Config")
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
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Choose an SSH config file to import")
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
            Text("Parsing SSH config...")
                .foregroundStyle(.secondary)
        }
    }

    private var parsedEmptyView: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "No Importable Entries",
            message: "The selected file contains no SSH host entries,\nor all entries use wildcard patterns.",
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
            Text("Failed to Parse Config")
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

            TableColumn("Host") { entry in
                hostCell(for: entry)
            }

            TableColumn("HostName") { entry in
                hostNameCell(for: entry)
            }

            TableColumn("Port") { entry in
                portCell(for: entry)
            }
            .width(50)

            TableColumn("User") { entry in
                userCell(for: entry)
            }
            .width(80)

            TableColumn("IdentityFile") { entry in
                identityFileCell(for: entry)
            }
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

            TableColumn("Host") { entry in
                hostCell(for: entry)
            }

            TableColumn("HostName") { entry in
                hostNameCell(for: entry)
            }

            TableColumn("Port") { entry in
                portCell(for: entry)
            }
            .width(50)

            TableColumn("User") { entry in
                userCell(for: entry)
            }
            .width(80)

            TableColumn("IdentityFile") { entry in
                identityFileCell(for: entry)
            }

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
                    .accessibilityLabel("Conflict action for \(entry.host)")
                    .accessibilityHint("Choose Skip to keep existing connection, or Overwrite to replace it")
                }
            }
            .width(100)
        }
    }

    // MARK: - Table Cell Views

    private func selectionBinding(for entry: SSHConfigEntry) -> Binding<Bool> {
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

    private func hostCell(for entry: SSHConfigEntry) -> some View {
        HStack(spacing: 4) {
            if entry.isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Text(entry.host)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel(for: entry))
        .accessibilityValue(viewModel.selectedIds.contains(entry.id) ? "Selected" : "Not selected")
        .accessibilityHint("Toggle to include or exclude this connection from import")
    }

    private func hostNameCell(for entry: SSHConfigEntry) -> some View {
        Text(entry.hostName ?? "\u{2014}")
            .foregroundStyle(entry.hostName == nil ? .tertiary : .primary)
            .lineLimit(1)
    }

    private func portCell(for entry: SSHConfigEntry) -> some View {
        Text("\(entry.port)")
            .monospacedDigit()
    }

    private func userCell(for entry: SSHConfigEntry) -> some View {
        Text(entry.user ?? "\u{2014}")
            .foregroundStyle(entry.user == nil ? .tertiary : .primary)
    }

    private func identityFileCell(for entry: SSHConfigEntry) -> some View {
        Text(entry.identityFile ?? "\u{2014}")
            .foregroundStyle(entry.identityFile == nil ? .tertiary : .primary)
            .lineLimit(1)
            .truncationMode(.middle)
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
            if viewModel.wildcardCount > 0 {
                Text("Skipped \(viewModel.wildcardCount) wildcard entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !viewModel.includeWarnings.isEmpty {
                Button {
                    viewModel.toggleIncludeWarningPopover()
                } label: {
                    Text("\(viewModel.includeWarnings.count) include warning(s)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $viewModel.includeWarningPopoverPresented) {
                    includeWarningsPopover
                }
            }
            if viewModel.effectiveImportCount == 0 && viewModel.selectedCount > 0 && viewModel.hasConflicts {
                Text("No new connections to import")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(footerAccessibilityLabel)
    }

    private var includeWarningsPopover: some View {
        VStack(alignment: .leading, spacing: UIConstants.smallSpacing) {
            Text("Include Warnings")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.includeWarnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
        .frame(maxHeight: 200)
    }

    // MARK: - Accessibility

    private func accessibilityRowLabel(for entry: SSHConfigEntry) -> String {
        let hostInfo = entry.hostName ?? "no host"
        let userInfo = entry.user ?? "default"
        if entry.isDuplicate {
            return "\(entry.host), duplicate detected, conflict action: \(entry.conflictAction.rawValue), \(hostInfo), port \(entry.port), user \(userInfo)"
        }
        return "\(entry.host), \(hostInfo), port \(entry.port), user \(userInfo)"
    }

    private var footerAccessibilityLabel: String {
        let selectedText = "\(viewModel.selectedCount) of \(viewModel.totalCount) selected"
        let wildcardText = viewModel.wildcardCount > 0
            ? "Skipped \(viewModel.wildcardCount) wildcard entries"
            : "No wildcard entries skipped"
        let warningText = !viewModel.includeWarnings.isEmpty
            ? "\(viewModel.includeWarnings.count) include warnings"
            : "No include warnings"
        return "\(selectedText). \(wildcardText). \(warningText)"
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
