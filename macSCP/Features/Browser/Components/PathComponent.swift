//
//  PathComponent.swift
//  macSCP
//
//  Breadcrumb path segment model. Relocated verbatim from FileBrowserViewModel
//  so the VM file stays focused on state and delegation (VM-SPLIT-01).
//

import Foundation

// MARK: - Path Component
struct PathComponent: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String

    static func == (lhs: PathComponent, rhs: PathComponent) -> Bool {
        lhs.path == rhs.path && lhs.name == rhs.name
    }

    /// Splits an absolute path into ordered breadcrumb segments, rooted at "/".
    static func breadcrumbs(from path: String) -> [PathComponent] {
        var components: [PathComponent] = []
        var current = ""
        for segment in path.split(separator: "/") {
            current += "/" + segment
            components.append(PathComponent(name: String(segment), path: current))
        }
        if components.isEmpty {
            components.append(PathComponent(name: "/", path: "/"))
        }
        return components
    }
}
