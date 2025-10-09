//
//  BreadcrumbView.swift
//  macSCP
//
//  Breadcrumb navigation component showing current path
//

import SwiftUI

struct BreadcrumbView: View {
    let pathComponents: [(name: String, path: String)]
    let onNavigate: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                        Button(action: {
                            onNavigate(component.path)
                        }) {
                            Text(component.name)
                                .font(.system(size: 12))
                                .foregroundColor(index == pathComponents.count - 1 ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)

                        if index < pathComponents.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
    }
}
