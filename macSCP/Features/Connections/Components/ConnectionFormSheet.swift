//
//  ConnectionFormSheet.swift
//  macSCP
//
//  Form for creating and editing connections
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
    let onTestConnection: ((Connection, String?) -> Void)?
    var testConnectionState: TestConnectionState = .idle
    var onResetTestState: (() -> Void)?

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
    @State private var touched: Set<Connection.ConnectionField> = []

    // S3-specific fields
    @State private var s3Region: String = "us-east-1"
    @State private var s3Bucket: String = ""
    @State private var s3Endpoint: String = ""
    @State private var s3SecretAccessKey: String = ""

    init(
        mode: ConnectionFormMode,
        savedPassword: String? = nil,
        folders: [Folder] = [],
        onSave: @escaping (Connection, String?) -> Void,
        onCancel: @escaping () -> Void,
        onTestConnection: ((Connection, String?) -> Void)? = nil,
        testConnectionState: TestConnectionState = .idle,
        onResetTestState: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.savedPassword = savedPassword
        self.folders = folders
        self.onSave = onSave
        self.onCancel = onCancel
        self.onTestConnection = onTestConnection
        self.testConnectionState = testConnectionState
        self.onResetTestState = onResetTestState
    }

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(mode.title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()

            Divider()

            Form {
                // Type picker (only in create mode)
                if !isEditMode {
                    Section {
                        Picker("Type", selection: $selectedType) {
                            ForEach(ConnectionType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedType) { _, newType in
                            iconName = newType.iconName
                            if newType == .sftp {
                                port = "22"
                            }
                            onResetTestState?()
                        }
                    }
                }

                // Connection details based on type
                Section("Connection") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("nameField")
                        .onChange(of: name) { _, _ in touched.insert(.name) }
                    if touched.contains(.name), let msg = fieldError(.name) {
                        Text(msg).font(.caption).foregroundStyle(.red)
                    }

                    if selectedType == .sftp {
                        TextField("Host", text: $host)
                            .accessibilityIdentifier("hostField")
                            .onChange(of: host) { _, _ in touched.insert(.host) }
                        if touched.contains(.host), let msg = fieldError(.host) {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                        TextField("Port", text: $port)
                            .accessibilityIdentifier("portField")
                            .onChange(of: port) { _, _ in touched.insert(.port) }
                        if touched.contains(.port), let msg = fieldError(.port) {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                        TextField("Username", text: $username)
                            .accessibilityIdentifier("usernameField")
                            .onChange(of: username) { _, _ in touched.insert(.username) }
                        if touched.contains(.username), let msg = fieldError(.username) {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                    } else if selectedType == .s3 {
                        TextField("Access Key ID", text: $username)
                            .accessibilityIdentifier("usernameField")
                            .onChange(of: username) { _, _ in touched.insert(.s3AccessKey) }
                        if touched.contains(.s3AccessKey), let msg = fieldError(.s3AccessKey) {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                        SecureField("Secret Access Key", text: $s3SecretAccessKey)
                        TextField("Bucket", text: $s3Bucket)
                            .onChange(of: s3Bucket) { _, _ in touched.insert(.s3Bucket) }
                        if touched.contains(.s3Bucket), let msg = fieldError(.s3Bucket) {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
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
                                    .onChange(of: privateKeyPath) { _, _ in touched.insert(.privateKeyPath) }
                                Button("Browse") {
                                    browseForKey()
                                }
                            }
                            if touched.contains(.privateKeyPath), let msg = fieldError(.privateKeyPath) {
                                Text(msg).font(.caption).foregroundStyle(.red)
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

            // Test Connection result banner
            testResultBanner

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cancelButton")

                Button("Test Connection") {
                    testConnection()
                }
                .keyboardShortcut("t", modifiers: .command)
                .buttonStyle(.bordered)
                .disabled(!isValid || testConnectionState == .testing)
                .accessibilityIdentifier("testConnectionButton")

                Button(mode.saveButtonTitle) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .accessibilityIdentifier("saveButton")
            }
            .padding()
        }
        .frame(width: 500, height: 640)
        .onAppear {
            loadExistingData()
        }
    }

    // MARK: - Test Connection

    @ViewBuilder
    private var testResultBanner: some View {
        switch testConnectionState {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Testing connection...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        case .success:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connection successful")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        case .failure(let msg):
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private func testConnection() {
        guard let onTestConnection else { return }
        let conn = buildCurrentConnection()
        let pw: String?
        if selectedType == .s3 {
            pw = s3SecretAccessKey.isEmpty ? nil : s3SecretAccessKey
        } else {
            pw = password.isEmpty ? nil : password
        }
        onTestConnection(conn, pw)
    }

    // MARK: - Validation

    private func fieldError(_ field: Connection.ConnectionField) -> String? {
        let portNumber = Int(port) ?? 0
        let conn = Connection(
            name: name,
            host: host,
            port: portNumber,
            username: username,
            authMethod: authMethod,
            privateKeyPath: authMethod == .privateKey ? privateKeyPath : nil,
            connectionType: selectedType,
            s3Bucket: s3Bucket.isEmpty ? nil : s3Bucket
        )
        return conn.validationError(for: field)
    }

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
        }
    }

    // MARK: - Save

    private func buildCurrentConnection() -> Connection {
        let portNumber = Int(port) ?? 22

        if case .edit(let existing) = mode {
            return Connection(
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
            return Connection(
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
    }

    private func save() {
        touched = Set(Connection.ConnectionField.allCases)
        let connection = buildCurrentConnection()

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
                .foregroundStyle(isHovering ? .red : .primary)

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(isHovering ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .padding(.vertical, 3)
        .background(.fill.tertiary, in: Capsule())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onRemove()
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
#Preview("Create") {
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
