//
//  EditorContentView.swift
//  macSCP
//
//  Editor content area with search highlighting support
//

import SwiftUI

struct EditorContentView: View {
    @Binding var fileContent: String
    let fontSize: CGFloat
    let showingSearchBar: Bool
    @ObservedObject var searchManager: SearchManager

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.textBackgroundColor)

            if !searchManager.searchText.isEmpty && showingSearchBar {
                // Show highlighted text (read-only during search)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(fileContent.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                                HStack {
                                    Text(searchManager.getAttributedLine(lineIndex: index, lineText: line, in: fileContent))
                                        .font(.system(size: fontSize, design: .monospaced))
                                        .textSelection(.enabled)
                                        .id(index)
                                    Spacer()
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: searchManager.scrollPosition) { _, newValue in
                        if let position = newValue {
                            withAnimation {
                                proxy.scrollTo(position, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                // Regular editable text editor
                TextEditor(text: $fileContent)
                    .font(.system(size: fontSize, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .onChange(of: fileContent) { _, _ in
                        if showingSearchBar && !searchManager.searchText.isEmpty {
                            searchManager.updateSearchMatches(in: fileContent)
                        }
                    }
            }
        }
    }
}
