//
//  SearchBarView.swift
//  macSCP
//
//  Search and replace bar for file editor
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var showingSearchBar: Bool

    let matchCount: Int
    let currentMatchIndex: Int
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplaceCurrent: () -> Void
    let onReplaceAll: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Find", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        onFindNext()
                    }

                if !searchText.isEmpty {
                    Text("\(currentMatchIndex)/\(matchCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)

                    Button(action: onFindPrevious) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)

                    Button(action: onFindNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)

                    Divider()
                        .frame(height: 12)

                    Text("Clear search to edit")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    showingSearchBar = false
                    searchText = ""
                    replaceText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Replace field
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Replace", text: $replaceText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                Button("Replace") {
                    onReplaceCurrent()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(matchCount == 0)

                Button("Replace All") {
                    onReplaceAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(matchCount == 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .background(Color(.controlBackgroundColor))
    }
}
