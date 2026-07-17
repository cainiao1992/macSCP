//
//  FileEditorViewModel.swift
//  macSCP
//
//  ViewModel for the file editor feature
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FileEditorViewModel {
    // MARK: - State
    private(set) var state: ViewState<Void> = .idle
    var error: AppError?

    var content: String
    private var savedContent: String

    let filePath: String
    let fileName: String

    // Search/Replace state
    var isShowingSearch = false
    var searchText: String = ""
    var replaceText: String = ""
    var searchResults: [Range<String.Index>] = []
    var currentSearchIndex: Int = 0
    var isCaseSensitive: Bool = false
    var isWholeWord: Bool = false

    // Pending replacement state — used by Coordinator to perform replaces via NSTextView
    var pendingSingleReplace: (range: Range<String.Index>, text: String)?
    var pendingReplaceAll: [(range: Range<String.Index>, text: String)]?

    // MARK: - Dependencies
    private let fileRepository: FileRepositoryProtocol
    private let s3Session: S3SessionProtocol?
    private let sftpSession: SFTPSessionProtocol?

    // MARK: - Initialization
    init(
        filePath: String,
        fileName: String,
        initialContent: String,
        fileRepository: FileRepositoryProtocol,
        s3Session: S3SessionProtocol? = nil,
        sftpSession: SFTPSessionProtocol? = nil
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.content = initialContent
        self.savedContent = initialContent
        self.fileRepository = fileRepository
        self.s3Session = s3Session
        self.sftpSession = sftpSession
    }

    // MARK: - Cleanup
    func cleanup() async {
        if let s3Session = s3Session {
            await s3Session.disconnect()
            logInfo("S3 session disconnected for editor", category: .s3)
        }
        if let sftpSession = sftpSession {
            await sftpSession.disconnect()
            logInfo("SFTP session disconnected for editor", category: .sftp)
        }
    }

    // MARK: - Computed Properties

    var hasChanges: Bool {
        content != savedContent
    }

    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    var characterCount: Int {
        content.count
    }

    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    var detectedLanguage: String? {
        LanguageDetectionService.language(for: fileName)
    }

    var currentSearchResult: Range<String.Index>? {
        guard !searchResults.isEmpty, currentSearchIndex < searchResults.count else { return nil }
        return searchResults[currentSearchIndex]
    }

    var searchStatusText: String {
        if searchText.isEmpty {
            return ""
        }
        if searchResults.isEmpty {
            return "No results"
        }
        return "\(currentSearchIndex + 1) of \(searchResults.count)"
    }

    // MARK: - File Operations

    func save() async {
        state = .loading

        do {
            try await fileRepository.writeFileContent(content, to: filePath)
            savedContent = content
            state = .success(())
            AnalyticsService.trackFileSaved(fileExtension: (fileName as NSString).pathExtension)
            logInfo("File saved: \(fileName)", category: s3Session != nil ? .s3 : .sftp)
        } catch {
            logError("Failed to save file: \(error)", category: .sftp)
            state = .error(AppError.from(error))
            self.error = AppError.from(error)
        }
    }

    func reload() async {
        state = .loading

        do {
            content = try await fileRepository.readFileContent(at: filePath)
            savedContent = content
            state = .success(())
            logInfo("File reloaded: \(fileName)", category: .sftp)
        } catch {
            logError("Failed to reload file: \(error)", category: .sftp)
            state = .error(AppError.from(error))
            self.error = AppError.from(error)
        }
    }

    func revertChanges() {
        content = savedContent
        logInfo("Changes reverted for: \(fileName)", category: .ui)
    }

    // MARK: - Search Operations

    func search() {
        guard !searchText.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            NotificationCenter.default.post(name: .editorSearchStateChanged, object: self)
            return
        }

        var options: String.CompareOptions = []
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }

        var results: [Range<String.Index>] = []
        var searchRange = content.startIndex..<content.endIndex

        while let range = content.range(of: searchText, options: options, range: searchRange) {
            if isWholeWord {
                let isWordBoundaryBefore = range.lowerBound == content.startIndex ||
                    !content[content.index(before: range.lowerBound)].isLetter
                let isWordBoundaryAfter = range.upperBound == content.endIndex ||
                    !content[range.upperBound].isLetter

                if isWordBoundaryBefore && isWordBoundaryAfter {
                    results.append(range)
                }
            } else {
                results.append(range)
            }

            searchRange = range.upperBound..<content.endIndex
        }

        searchResults = results
        currentSearchIndex = results.isEmpty ? 0 : 0
        NotificationCenter.default.post(name: .editorSearchStateChanged, object: self)
    }

    func findNext() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        NotificationCenter.default.post(name: .editorSearchStateChanged, object: self)
    }

    func findPrevious() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        NotificationCenter.default.post(name: .editorSearchStateChanged, object: self)
    }

    func replaceCurrent() {
        guard let range = currentSearchResult else { return }
        pendingSingleReplace = (range: range, text: replaceText)
        // Do NOT mutate content here — Coordinator will perform via NSTextView
        // textDidChange will sync content back, then search() will be triggered
    }

    func replaceAll() {
        guard !searchText.isEmpty else { return }

        var options: String.CompareOptions = []
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }

        var replacements: [(range: Range<String.Index>, text: String)] = []
        var searchRange = content.startIndex..<content.endIndex

        while let range = content.range(of: searchText, options: options, range: searchRange) {
            if isWholeWord {
                let isWordBoundaryBefore = range.lowerBound == content.startIndex ||
                    !content[content.index(before: range.lowerBound)].isLetter
                let isWordBoundaryAfter = range.upperBound == content.endIndex ||
                    !content[range.upperBound].isLetter
                if isWordBoundaryBefore && isWordBoundaryAfter {
                    replacements.append((range: range, text: replaceText))
                }
            } else {
                replacements.append((range: range, text: replaceText))
            }
            searchRange = range.upperBound..<content.endIndex
        }

        pendingReplaceAll = replacements
        // Do NOT mutate content — Coordinator will perform via NSTextView in reverse order
    }

    func toggleSearch() {
        isShowingSearch.toggle()
        if !isShowingSearch {
            searchText = ""
            replaceText = ""
            searchResults = []
            currentSearchIndex = 0
        }
        NotificationCenter.default.post(name: .editorSearchStateChanged, object: self)
    }

    // MARK: - UI Actions

    func clearError() {
        error = nil
    }
}
