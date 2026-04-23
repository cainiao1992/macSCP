//
//  BreadcrumbView.swift
//  macSCP
//
//  Finder-style path bar for the file browser
//

import SwiftUI

struct BreadcrumbView: View {
    let components: [PathComponent]
    let currentPath: String
    let onNavigate: (String) -> Void

    @State private var hoveredPath: String?
    @State private var isEditing = false
    @State private var editPath: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                pathEditor
            } else {
                breadcrumbContent
            }
        }
        .frame(height: 28)
        .background(.bar)
    }

    private var pathEditor: some View {
        TextField("Path", text: $editPath)
            .font(.system(size: 12, design: .monospaced))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .focused($isFieldFocused)
            .onSubmit {
                let trimmed = editPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onNavigate(trimmed)
                }
                isEditing = false
            }
            .onExitCommand {
                isEditing = false
            }
    }

    private var breadcrumbContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Root
                    pathButton(icon: "externaldrive.fill", path: "/", isLast: components.isEmpty)

                    ForEach(components) { component in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, 1)

                        pathButton(text: component.name, path: component.path, isLast: component.path == components.last?.path)
                            .id(component.path)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .onChange(of: components) { _, newComponents in
                if let lastPath = newComponents.last?.path {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastPath, anchor: .trailing)
                    }
                }
            }
        }
        .onTapGesture(count: 2) {
            editPath = currentPath
            isEditing = true
            isFieldFocused = true
        }
    }

    @ViewBuilder
    private func pathButton(icon: String? = nil, text: String? = nil, path: String, isLast: Bool) -> some View {
        let isHovered = hoveredPath == path

        Button {
            onNavigate(path)
        } label: {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 12, weight: isLast ? .medium : .regular))
                }
            }
            .foregroundStyle(isLast ? .primary : .tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredPath = hovering ? path : nil
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        BreadcrumbView(
            components: [],
            currentPath: "/",
            onNavigate: { _ in }
        )

        Divider()

        BreadcrumbView(
            components: [
                PathComponent(name: "home", path: "/home"),
                PathComponent(name: "user", path: "/home/user"),
                PathComponent(name: "documents", path: "/home/user/documents")
            ],
            currentPath: "/home/user/documents",
            onNavigate: { _ in }
        )

        Divider()

        BreadcrumbView(
            components: [
                PathComponent(name: "var", path: "/var"),
                PathComponent(name: "www", path: "/var/www"),
                PathComponent(name: "html", path: "/var/www/html"),
                PathComponent(name: "myproject", path: "/var/www/html/myproject"),
                PathComponent(name: "src", path: "/var/www/html/myproject/src")
            ],
            currentPath: "/var/www/html/myproject/src",
            onNavigate: { _ in }
        )
    }
    .frame(width: 400)
}
