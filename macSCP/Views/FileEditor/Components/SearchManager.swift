//
//  SearchManager.swift
//  macSCP
//
//  Manager for handling search and replace operations in file editor
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchManager: ObservableObject {
    @Published var searchText: String = ""
    @Published var replaceText: String = ""
    @Published var matchCount: Int = 0
    @Published var currentMatchIndex: Int = 0
    @Published var scrollPosition: Int?

    private(set) var searchRanges: [Range<String.Index>] = []

    func updateSearchMatches(in content: String) {
        guard !searchText.isEmpty else {
            matchCount = 0
            currentMatchIndex = 0
            searchRanges = []
            return
        }

        let matches = content.ranges(of: searchText, options: .caseInsensitive)
        searchRanges = matches
        matchCount = matches.count
        currentMatchIndex = matchCount > 0 ? 1 : 0

        // Calculate scroll position for current match
        updateScrollPosition(in: content)
    }

    func findNext() {
        guard matchCount > 0 else { return }
        currentMatchIndex = currentMatchIndex < matchCount ? currentMatchIndex + 1 : 1
    }

    func findPrevious() {
        guard matchCount > 0 else { return }
        currentMatchIndex = currentMatchIndex > 1 ? currentMatchIndex - 1 : matchCount
    }

    func replaceCurrent(in content: inout String) {
        guard !searchText.isEmpty, matchCount > 0, currentMatchIndex > 0 else { return }

        if currentMatchIndex <= searchRanges.count {
            let range = searchRanges[currentMatchIndex - 1]
            content.replaceSubrange(range, with: replaceText)
            updateSearchMatches(in: content)
        }
    }

    func replaceAll(in content: inout String) {
        guard !searchText.isEmpty else { return }

        content = content.replacingOccurrences(of: searchText, with: replaceText, options: .caseInsensitive)
        updateSearchMatches(in: content)
    }

    func getAttributedLine(lineIndex: Int, lineText: String, in content: String) -> AttributedString {
        var attributedLine = AttributedString(lineText)

        // Calculate the character offset for this line
        let lines = content.components(separatedBy: .newlines)
        var charOffset = 0
        for i in 0..<lineIndex {
            charOffset += lines[i].count + 1 // +1 for newline
        }

        let lineStartIndex = content.index(content.startIndex, offsetBy: charOffset)
        let lineEndIndex = content.index(lineStartIndex, offsetBy: lineText.count)
        let lineRange = lineStartIndex..<lineEndIndex

        // Find matches in this line
        for (index, range) in searchRanges.enumerated() {
            if range.overlaps(lineRange) {
                // Calculate the position within the line
                let matchStart = max(range.lowerBound, lineStartIndex)
                let matchEnd = min(range.upperBound, lineEndIndex)

                if matchStart < matchEnd {
                    let startOffset = content.distance(from: lineStartIndex, to: matchStart)
                    let endOffset = content.distance(from: lineStartIndex, to: matchEnd)

                    guard startOffset >= 0 && endOffset <= lineText.count else { continue }

                    let attrStart = attributedLine.index(attributedLine.startIndex, offsetByCharacters: startOffset)
                    let attrEnd = attributedLine.index(attributedLine.startIndex, offsetByCharacters: endOffset)

                    if attrStart < attrEnd {
                        let attrRange = attrStart..<attrEnd

                        if index == currentMatchIndex - 1 {
                            // Current match - bright yellow
                            attributedLine[attrRange].backgroundColor = .yellow
                            attributedLine[attrRange].foregroundColor = .black
                        } else {
                            // Other matches - light yellow
                            attributedLine[attrRange].backgroundColor = Color.yellow.opacity(0.3)
                        }
                    }
                }
            }
        }

        return attributedLine
    }

    private func updateScrollPosition(in content: String) {
        guard currentMatchIndex > 0, currentMatchIndex <= searchRanges.count else {
            scrollPosition = nil
            return
        }

        let currentRange = searchRanges[currentMatchIndex - 1]
        let beforeMatch = String(content[..<currentRange.lowerBound])
        let lineNumber = beforeMatch.components(separatedBy: .newlines).count - 1
        scrollPosition = max(0, lineNumber)
    }

    func reset() {
        searchText = ""
        replaceText = ""
        matchCount = 0
        currentMatchIndex = 0
        searchRanges = []
        scrollPosition = nil
    }
}

// Extension for finding all ranges of a substring
extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }

        return ranges
    }
}
