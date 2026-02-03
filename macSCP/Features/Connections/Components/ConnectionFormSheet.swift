//
//  ConnectionFormSheet.swift
//  macSCP
//
//  Form for creating and editing connections - Two-step wizard
//

import SwiftUI

enum ConnectionFormMode {
    case create
    case edit(Connection)

    var title: String {
        switch self {
        case .create: return "New Connection"
        case .edit: return "Edit Connection"
        }
    }

    var saveButtonTitle: String {
        switch self {
        case .create: return "Create"
        case .edit: return "Save"
        }
    }
}

struct ConnectionFormSheet: View {
    let mode: ConnectionFormMode
    let savedPassword: String?
    let folders: [Folder]
    let onSave: (Connection, String?) -> Void
    let onCancel: () -> Void

    // Wizard state
    @State private var currentStep: FormStep = .selectType
    @State private var selectedType: ConnectionType = .sftp

    // Form fields
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: AuthMethod = .password
    @State private var privateKeyPath: String = ""
    @State private var savePassword: Bool = false
    @State private var password: String = ""
    @State private var description: String = ""
    @State private var iconName: String = "server.rack"
    @State private var selectedFolderId: UUID?
    @State private var tags: [String] = []
    @State private var newTag: String = ""

    // S3-specific fields
    @State private var s3Region: String = "us-east-1"
    @State private var s3Bucket: String = ""
    @State private var s3Endpoint: String = ""
    @State private var s3SecretAccessKey: String = ""

    enum FormStep {
        case selectType
        case fillDetails
    }

    init(
        mode: ConnectionFormMode,
        savedPassword: String? = nil,
        folders: [Folder] = [],
        onSave: @escaping (Connection, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.savedPassword = savedPassword
        self.folders = folders
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content based on step
            if isEditMode {
                // Edit mode: skip type selection, go straight to form
                detailsFormView
            } else {
                switch currentStep {
                case .selectType:
                    typeSelectionView
                case .fillDetails:
                    detailsFormView
                }
            }
        }
        .frame(width: 500, height: currentStep == .selectType && !isEditMode ? 480 : 580)
        .animation(.easeInOut(duration: 0.2), value: currentStep)
        .onAppear {
            loadExistingData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Back button (only in step 2 for create mode)
            if currentStep == .fillDetails && !isEditMode {
                Button {
                    withAnimation {
                        currentStep = .selectType
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Title
            VStack(spacing: 2) {
                Text(headerTitle)
                    .font(.headline)

                if currentStep == .selectType && !isEditMode {
                    Text("Step 1 of 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !isEditMode {
                    Text("Step 2 of 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var headerTitle: String {
        if isEditMode {
            return "Edit Connection"
        }
        switch currentStep {
        case .selectType:
            return "Choose Connection Type"
        case .fillDetails:
            return "Configure \(selectedType.displayName)"
        }
    }

    // MARK: - Step 1: Type Selection

    private var typeSelectionView: some View {
        VStack(spacing: 0) {
            // Grid of connection types
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(ConnectionType.allCases, id: \.self) { type in
                        ConnectionTypeCard(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedType = type
                                iconName = type.iconName
                                if type == .sftp {
                                    port = "22"
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Continue") {
                    withAnimation {
                        currentStep = .fillDetails
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - Step 2: Details Form

    private var detailsFormView: some View {
        VStack(spacing: 0) {
            Form {
                // Show selected type badge in edit mode or step 2
                Section {
                    HStack {
                        Image(systemName: selectedType.iconName)
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                        Text(selectedType.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(selectedType.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Connection details based on type
                Section("Connection") {
                    TextField("Name", text: $name)

                    if selectedType == .sftp {
                        TextField("Host", text: $host)
                        TextField("Port", text: $port)
                        TextField("Username", text: $username)
                    } else if selectedType == .s3 {
                        TextField("Access Key ID", text: $username)
                        SecureField("Secret Access Key", text: $s3SecretAccessKey)
                        TextField("Bucket", text: $s3Bucket)
                        TextField("Region", text: $s3Region)
                            .textContentType(.none)
                        TextField("Custom Endpoint (optional)", text: $s3Endpoint)
                            .textContentType(.URL)
                    }
                }

                // Authentication (SFTP only)
                if selectedType == .sftp {
                    Section("Authentication") {
                        Picker("Method", selection: $authMethod) {
                            ForEach(AuthMethod.allCases, id: \.self) { method in
                                Text(method.displayName).tag(method)
                            }
                        }

                        if authMethod == .password {
                            SecureField("Password", text: $password)
                            Toggle("Save password in Keychain", isOn: $savePassword)
                        } else {
                            HStack {
                                TextField("Private Key Path", text: $privateKeyPath)
                                Button("Browse") {
                                    browseForKey()
                                }
                            }
                        }
                    }
                } else if selectedType == .s3 {
                    Section("Security") {
                        Toggle("Save credentials in Keychain", isOn: $savePassword)
                    }
                }

                // Organization
                Section("Organization") {
                    Picker("Folder", selection: $selectedFolderId) {
                        Text("None").tag(nil as UUID?)
                        ForEach(folders) { folder in
                            Text(folder.name).tag(folder.id as UUID?)
                        }
                    }

                    // Tags
                    LabeledContent("Tags") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("", text: $newTag)
                                    .onSubmit {
                                        addTag()
                                    }
                                Button {
                                    addTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(newTag.trimmed.isEmpty ? Color.gray : Color.blue)
                                }
                                .buttonStyle(.plain)
                                .disabled(newTag.trimmed.isEmpty)
                            }

                            if !tags.isEmpty {
                                FlowLayout(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        TagChip(tag: tag) {
                                            removeTag(tag)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Optional
                Section("Optional") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)

                    IconPickerRow(selectedIcon: $iconName)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                if !isEditMode {
                    Button {
                        withAnimation {
                            currentStep = .selectType
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Back")
                        }
                    }
                }

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(mode.saveButtonTitle) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        switch selectedType {
        case .sftp:
            return !name.trimmed.isEmpty &&
                !host.trimmed.isEmpty &&
                !username.trimmed.isEmpty &&
                (Int(port) ?? 0) > 0 && (Int(port) ?? 0) <= 65535 &&
                (authMethod == .password || !privateKeyPath.trimmed.isEmpty)
        case .s3:
            return !name.trimmed.isEmpty &&
                !username.trimmed.isEmpty &&
                !s3Bucket.trimmed.isEmpty
        }
    }

    // MARK: - Data Loading

    private func loadExistingData() {
        if case .edit(let connection) = mode {
            name = connection.name
            host = connection.host
            port = String(connection.port)
            username = connection.username
            authMethod = connection.authMethod
            privateKeyPath = connection.privateKeyPath ?? ""
            savePassword = connection.savePassword
            description = connection.description ?? ""
            iconName = connection.iconName
            selectedFolderId = connection.folderId
            tags = connection.tags
            selectedType = connection.connectionType
            s3Region = connection.s3Region ?? "us-east-1"
            s3Bucket = connection.s3Bucket ?? ""
            s3Endpoint = connection.s3Endpoint ?? ""

            if let saved = savedPassword {
                if selectedType == .s3 {
                    s3SecretAccessKey = saved
                } else {
                    password = saved
                }
            }

            // Skip to details in edit mode
            currentStep = .fillDetails
        }
    }

    // MARK: - Save

    private func save() {
        let portNumber = Int(port) ?? 22

        let connection: Connection
        if case .edit(let existing) = mode {
            connection = Connection(
                id: existing.id,
                name: name.trimmed,
                host: selectedType == .sftp ? host.trimmed : "",
                port: portNumber,
                username: username.trimmed,
                authMethod: authMethod,
                privateKeyPath: authMethod == .privateKey ? privateKeyPath.trimmed : nil,
                savePassword: savePassword,
                description: description.trimmed.isEmpty ? nil : description.trimmed,
                tags: tags,
                iconName: iconName,
                folderId: selectedFolderId,
                createdAt: existing.createdAt,
                updatedAt: Date(),
                connectionType: selectedType,
                s3Region: selectedType == .s3 ? s3Region.trimmed : nil,
                s3Bucket: selectedType == .s3 ? s3Bucket.trimmed : nil,
                s3Endpoint: selectedType == .s3 && !s3Endpoint.trimmed.isEmpty ? s3Endpoint.trimmed : nil
            )
        } else {
            connection = Connection(
                name: name.trimmed,
                host: selectedType == .sftp ? host.trimmed : "",
                port: portNumber,
                username: username.trimmed,
                authMethod: authMethod,
                privateKeyPath: authMethod == .privateKey ? privateKeyPath.trimmed : nil,
                savePassword: savePassword,
                description: description.trimmed.isEmpty ? nil : description.trimmed,
                tags: tags,
                iconName: iconName,
                folderId: selectedFolderId,
                connectionType: selectedType,
                s3Region: selectedType == .s3 ? s3Region.trimmed : nil,
                s3Bucket: selectedType == .s3 ? s3Bucket.trimmed : nil,
                s3Endpoint: selectedType == .s3 && !s3Endpoint.trimmed.isEmpty ? s3Endpoint.trimmed : nil
            )
        }

        let passwordToSave: String?
        if selectedType == .s3 {
            passwordToSave = savePassword && !s3SecretAccessKey.isEmpty ? s3SecretAccessKey : nil
        } else {
            passwordToSave = savePassword && !password.isEmpty ? password : nil
        }
        onSave(connection, passwordToSave)
    }

    // MARK: - Helpers

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")

        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }

    private func addTag() {
        let tag = newTag.trimmed
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Connection Type Card
struct ConnectionTypeCard: View {
    let type: ConnectionType
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue : .blue.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: type.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .blue)
                }

                // Text
                VStack(spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(type.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.08) : (isHovering ? Color.primary.opacity(0.04) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.blue : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.1), value: isHovering)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Icon Picker Row
struct IconPickerRow: View {
    @Binding var selectedIcon: String
    @State private var showingIconSelector = false

    var body: some View {
        HStack {
            Text("Icon")
            Spacer()
            Button {
                showingIconSelector.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(selectedIcon)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingIconSelector, arrowEdge: .trailing) {
                IconSelectorView(selectedIcon: $selectedIcon)
            }
        }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 11, weight: .medium))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isHovering ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue.opacity(0.1), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.blue.opacity(0.2), lineWidth: 1)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview
#Preview("Create - Step 1") {
    ConnectionFormSheet(
        mode: .create,
        folders: [
            Folder(name: "Production"),
            Folder(name: "Development")
        ],
        onSave: { _, _ in },
        onCancel: {}
    )
}

#Preview("Edit") {
    ConnectionFormSheet(
        mode: .edit(Connection(
            name: "Test Server",
            host: "test.example.com",
            username: "admin",
            tags: ["production", "critical"]
        )),
        savedPassword: "secret123",
        folders: [
            Folder(name: "Production"),
            Folder(name: "Development")
        ],
        onSave: { _, _ in },
        onCancel: {}
    )
}
