//
//  SearchReplaceBar.swift
//  macSCP
//
//  Search and replace bar for the file editor
//

import SwiftUI

struct SearchReplaceBar: View {
    @Bindable var viewModel: FileEditorViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var isShowingReplaceAllConfirmation = false

    var body: some View {
        VStack(spacing: UIConstants.smallSpacing) {
            // Search row
            HStack(spacing: UIConstants.smallSpacing) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        viewModel.search()
                    }
                    .onChange(of: viewModel.searchText) {
                        viewModel.search()
                    }

                // Options
                Toggle(isOn: $viewModel.isCaseSensitive) {
                    Text("Aa")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .help("Case sensitive")
                .onChange(of: viewModel.isCaseSensitive) {
                    viewModel.search()
                }

                Toggle(isOn: $viewModel.isWholeWord) {
                    Image(systemName: "textformat")
                }
                .toggleStyle(.button)
                .help("Whole word")
                .onChange(of: viewModel.isWholeWord) {
                    viewModel.search()
                }

                // Navigation
                Button {
                    viewModel.findPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.searchResults.isEmpty)
                .help("Previous Match")
                .accessibilityLabel("Previous match")

                Button {
                    viewModel.findNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.searchResults.isEmpty)
                .help("Next Match")
                .accessibilityLabel("Next match")

                // Status
                Text(viewModel.searchStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 60)

                // Close
                Button {
                    viewModel.toggleSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Search")
                .accessibilityLabel("Close search")
            }

            // Replace row
            HStack(spacing: UIConstants.smallSpacing) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Replace", text: $viewModel.replaceText)
                    .textFieldStyle(.plain)

                Button("Replace") {
                    viewModel.replaceCurrent()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.searchResults.isEmpty)

                Button("Replace All") {
                    isShowingReplaceAllConfirmation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.searchResults.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, UIConstants.smallSpacing)
        .background(Color(.controlBackgroundColor))
        .confirmationDialog(
            "Replace All",
            isPresented: $isShowingReplaceAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace \(viewModel.searchResults.count) Occurrences", role: .destructive) {
                viewModel.replaceAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all \(viewModel.searchResults.count) occurrences of \"\(viewModel.searchText)\" in the file.")
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    SearchReplaceBar(viewModel: FileEditorViewModel(
        filePath: "/test.txt",
        fileName: "test.txt",
        initialContent: "Hello, World! Hello again!",
        fileRepository: FileRepository(sftpSession: SystemSFTPSession())
    ))
}
