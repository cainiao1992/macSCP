//
//  FileEditorViewModelTests.swift
//  macSCPTests
//
//  Unit tests for FileEditorViewModel
//

import XCTest
@testable import macSCP

@MainActor
final class FileEditorViewModelTests: XCTestCase {
    var sut: FileEditorViewModel!
    var mockFileRepository: MockFileRepository!

    let testContent = "Hello, World!\nThis is a test file.\nLine 3."

    override func setUp() async throws {
        try await super.setUp()
        mockFileRepository = MockFileRepository()

        sut = FileEditorViewModel(
            filePath: "/test/file.txt",
            fileName: "file.txt",
            initialContent: testContent,
            fileRepository: mockFileRepository
        )
    }

    override func tearDown() async throws {
        highlightViewModel = nil
        sut = nil
        mockFileRepository = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(sut.content, testContent)
        XCTAssertEqual(sut.filePath, "/test/file.txt")
        XCTAssertEqual(sut.fileName, "file.txt")
        XCTAssertFalse(sut.hasChanges)
    }

    // MARK: - Content Statistics Tests

    func testLineCount() {
        XCTAssertEqual(sut.lineCount, 3)
    }

    func testWordCount() {
        // "Hello, World! This is a test file. Line 3." = 9 words
        XCTAssertEqual(sut.wordCount, 9)
    }

    func testCharacterCount() {
        XCTAssertEqual(sut.characterCount, testContent.count)
    }

    // MARK: - Change Detection Tests

    func testHasChanges_WhenContentModified() {
        // When
        sut.content = "Modified content"

        // Then
        XCTAssertTrue(sut.hasChanges)
    }

    func testHasChanges_WhenContentReverted() {
        // Given
        sut.content = "Modified content"

        // When
        sut.revertChanges()

        // Then
        XCTAssertFalse(sut.hasChanges)
        XCTAssertEqual(sut.content, testContent)
    }

    // MARK: - Save Tests

    func testSave_Success() async {
        // Given
        sut.content = "New content"

        // When
        await sut.save()

        // Then
        XCTAssertTrue(mockFileRepository.writeFileContentCalled)
        XCTAssertEqual(mockFileRepository.lastWriteContent, "New content")
        XCTAssertEqual(mockFileRepository.lastWritePath, "/test/file.txt")
    }

    func testSave_Error() async {
        // Given
        mockFileRepository.mockError = AppError.fileWriteFailed

        // When
        await sut.save()

        // Then
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Reload Tests

    func testReload_Success() async {
        // Given
        mockFileRepository.mockFileContent = "Reloaded content"

        // When
        await sut.reload()

        // Then
        XCTAssertTrue(mockFileRepository.readFileContentCalled)
        XCTAssertEqual(sut.content, "Reloaded content")
    }

    // MARK: - Search Tests

    func testSearch_FindsMatches() {
        // When
        sut.searchText = "test"
        sut.search()

        // Then
        XCTAssertEqual(sut.searchResults.count, 1)
    }

    func testSearch_CaseSensitive() {
        // Given
        sut.isCaseSensitive = true

        // When
        sut.searchText = "Test"
        sut.search()

        // Then
        XCTAssertEqual(sut.searchResults.count, 0)
    }

    func testSearch_CaseInsensitive() {
        // Given
        sut.isCaseSensitive = false

        // When
        sut.searchText = "HELLO"
        sut.search()

        // Then
        XCTAssertEqual(sut.searchResults.count, 1)
    }

    func testSearch_EmptyText() {
        // When
        sut.searchText = ""
        sut.search()

        // Then
        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    func testSearchStatusText_NoResults() {
        // When
        sut.searchText = "notfound"
        sut.search()

        // Then
        XCTAssertEqual(sut.searchStatusText, "No results")
    }

    func testSearchStatusText_WithResults() {
        // When
        sut.searchText = "test"
        sut.search()

        // Then
        XCTAssertEqual(sut.searchStatusText, "1 of 1")
    }

    // MARK: - Navigation Tests

    func testFindNext() {
        // Given - use content with multiple occurrences
        sut.content = "test test test"
        sut.searchText = "test"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 3)
        XCTAssertEqual(sut.currentSearchIndex, 0)

        // When
        sut.findNext()

        // Then
        XCTAssertEqual(sut.currentSearchIndex, 1)
    }

    func testFindPrevious() {
        // Given - use content with multiple occurrences
        sut.content = "test test test"
        sut.searchText = "test"
        sut.search()
        sut.findNext() // Move to index 1

        // When
        sut.findPrevious()

        // Then
        XCTAssertEqual(sut.currentSearchIndex, 0)
    }

    // MARK: - Replace Tests

    func testReplaceCurrent() {
        sut.content = "Hello World"
        sut.searchText = "World"
        sut.replaceText = "Universe"
        sut.search()

        sut.replaceCurrent()

        XCTAssertNotNil(sut.pendingSingleReplace, "Should set pending single replace signal")
        XCTAssertEqual(sut.pendingSingleReplace?.text, "Universe")
    }

    func testReplaceAll() {
        sut.content = "hello hello hello"
        sut.searchText = "hello"
        sut.replaceText = "hi"
        sut.search()

        sut.replaceAll()

        XCTAssertNotNil(sut.pendingReplaceAll, "Should set pending replace all signal")
        XCTAssertEqual(sut.pendingReplaceAll?.count, 3)
    }

    // MARK: - Search Highlight Bug Tests

    func testSearch_ProgressiveTypingThenClearHighlight() {
        // Simulates: content "Test", type "test", then backspace to ""
        sut.content = "Test"

        sut.searchText = "t"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 2, "'t' should find 2 matches in 'Test'")
        let firstRange = sut.searchResults[0]
        XCTAssertEqual(String(sut.content[firstRange]), "T")

        sut.searchText = "te"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 1, "'te' should find 1 match in 'Test'")
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Te")

        sut.searchText = "tes"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Tes")

        sut.searchText = "test"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Test")

        // Backspace all the way to empty
        sut.searchText = ""
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 0, "Empty search should have no results")
        XCTAssertEqual(sut.currentSearchIndex, 0)
    }

    func testSearch_NonExistentTextReturnsEmpty() {
        // "tett" does NOT exist in "Test"
        sut.content = "Test"
        sut.searchText = "tett"
        sut.search()

        XCTAssertEqual(sut.searchResults.count, 0, "'tett' should not match anything in 'Test'")
    }

    func testSearch_BacktrackFromFullToPartial() {
        // Type "test" then backspace to "te" — should highlight "Te" not "Test"
        sut.content = "Test"

        sut.searchText = "test"
        sut.search()
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Test")

        sut.searchText = "tes"
        sut.search()
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Tes")

        sut.searchText = "te"
        sut.search()
        XCTAssertEqual(String(sut.content[sut.searchResults[0]]), "Te")
        XCTAssertEqual(sut.searchResults.count, 1)

        sut.searchText = "tett"
        sut.search()
        XCTAssertTrue(sut.searchResults.isEmpty, "'tett' should not match 'Test'")
    }

    func testSearch_ResultRangesMatchActualContent() {
        // Verify that every search result range corresponds to the actual content
        sut.content = "abc ABC abc"
        sut.searchText = "abc"
        sut.search()

        XCTAssertEqual(sut.searchResults.count, 3)
        for (i, range) in sut.searchResults.enumerated() {
            let matched = String(sut.content[range])
            XCTAssertEqual(matched.lowercased(), "abc", "Result \(i): matched '\(matched)' instead of 'abc'")
        }
    }

    func testSearch_EmptyAfterEveryStep() {
        // After every step, clearing search should yield empty results
        sut.content = "Hello Test World"
        let searches = ["t", "te", "tes", "test", "tes", "te", "t", ""]

        for query in searches {
            sut.searchText = query
            sut.search()

            if query.isEmpty {
                XCTAssertTrue(sut.searchResults.isEmpty, "Empty query should have no results")
            }
        }
    }

    func testSearch_ResultRangesAlwaysExactLength() {
        sut.content = "Test Testing tested"
        let queries = ["t", "te", "tes", "test", "testi"]

        for query in queries {
            sut.searchText = query
            sut.search()

            for (i, range) in sut.searchResults.enumerated() {
                let matchedLength = sut.content.distance(from: range.lowerBound, to: range.upperBound)
                XCTAssertEqual(
                    matchedLength, query.count,
                    "Result \(i) for '\(query)': matched length \(matchedLength) != query length \(query.count), matched: '\(sut.content[range])'"
                )
            }
        }
    }

    // MARK: - Search + Notification Flow Tests

    func testSearch_PostsNotificationWhenResultsChange() {
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .editorSearchStateChanged, object: nil, queue: .main
        ) { _ in notificationCount += 1 }

        sut.content = "Test"
        sut.searchText = "te"
        sut.search()
        XCTAssertEqual(notificationCount, 1)

        sut.searchText = "tes"
        sut.search()
        XCTAssertEqual(notificationCount, 2)

        sut.searchText = ""
        sut.search()
        XCTAssertEqual(notificationCount, 3)

        NotificationCenter.default.removeObserver(observer)
    }

    func testSearch_PostsNotificationWhenNavigating() {
        sut.content = "test test test"
        sut.searchText = "test"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 3)

        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .editorSearchStateChanged, object: nil, queue: .main
        ) { _ in notificationCount += 1 }

        sut.findNext()
        XCTAssertEqual(notificationCount, 1)
        XCTAssertEqual(sut.currentSearchIndex, 1)

        sut.findPrevious()
        XCTAssertEqual(notificationCount, 2)
        XCTAssertEqual(sut.currentSearchIndex, 0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testSearch_ClearResultsOnEmptySearchText() {
        sut.content = "Test"
        sut.searchText = "te"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 1)

        sut.searchText = ""
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 0)
        XCTAssertEqual(sut.currentSearchIndex, 0)
    }

    func testSearch_ClearResultsOnNonMatchingText() {
        sut.content = "Test"
        sut.searchText = "test"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 1)

        sut.searchText = "tett"
        sut.search()
        XCTAssertEqual(sut.searchResults.count, 0, "'tett' should not match 'Test'")
    }

    // MARK: - Toggle Search Tests

    func testToggleSearch_ShowsSearch() {
        sut.toggleSearch()
        XCTAssertTrue(sut.isShowingSearch)
    }

    func testToggleSearch_HidesAndClearsSearch() {
        sut.isShowingSearch = true
        sut.searchText = "test"
        sut.search()

        sut.toggleSearch()

        XCTAssertFalse(sut.isShowingSearch)
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    // MARK: - NSLayoutManager Highlight Tests

    private var highlightViewModel: FileEditorViewModel!

    private func makeTextView(content: String) -> (NSTextView, NSLayoutManager) {
        let textStorage = NSTextStorage(string: content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), textContainer: textContainer)
        return (textView, layoutManager)
    }

    private func countHighlights(layoutManager: NSLayoutManager, length: Int) -> Int {
        var count = 0
        var pos = 0
        while pos < length {
            var effectiveRange = NSRange()
            let value = layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: pos, longestEffectiveRange: &effectiveRange, in: NSRange(location: 0, length: length))
            if value != nil { count += 1 }
            pos = effectiveRange.upperBound
            if effectiveRange.length == 0 { break }
        }
        return count
    }

    func testHighlight_AddThenRemoveWholeRange() {
        let content = "Test"
        let (_, layoutManager) = makeTextView(content: content)
        let wholeRange = NSRange(location: 0, length: content.utf16.count)

        layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: NSRange(location: 0, length: 2))
        XCTAssertEqual(countHighlights(layoutManager: layoutManager, length: content.utf16.count), 1)

        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: wholeRange)
        XCTAssertEqual(countHighlights(layoutManager: layoutManager, length: content.utf16.count), 0)
    }

    func testHighlight_RemoveThenAddSameRange() {
        let content = "Test"
        let (_, layoutManager) = makeTextView(content: content)
        let wholeRange = NSRange(location: 0, length: content.utf16.count)

        layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: NSRange(location: 0, length: 4))
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: wholeRange)
        layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: NSRange(location: 0, length: 2))

        XCTAssertEqual(countHighlights(layoutManager: layoutManager, length: content.utf16.count), 1)
    }

    func testHighlight_FullSearchFlow_ProgressiveTyping() {
        let content = "Test"
        let (_, layoutManager) = makeTextView(content: content)
        let wholeRange = NSRange(location: 0, length: content.utf16.count)

        highlightViewModel = FileEditorViewModel(
            filePath: "/test.txt",
            fileName: "test.txt",
            initialContent: content,
            fileRepository: MockFileRepository()
        )
        let vm = highlightViewModel!

        func applyHighlight() {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: wholeRange)
            guard !vm.searchText.isEmpty, !vm.searchResults.isEmpty else { return }
            let stringRange = vm.searchResults[vm.currentSearchIndex]
            let nsRange = NSRange(stringRange, in: vm.content)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: NSColor.yellow, forCharacterRange: nsRange)
        }

        let hlCount = { self.countHighlights(layoutManager: layoutManager, length: content.utf16.count) }

        vm.searchText = "t"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 1, "After 't'")
        XCTAssertEqual(vm.searchResults.count, 2)

        vm.searchText = "te"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 1, "After 'te'")

        vm.searchText = "tes"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 1, "After 'tes'")

        vm.searchText = "test"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 1, "After 'test'")

        vm.searchText = "tes"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 1, "After backspace to 'tes'")

        vm.searchText = ""; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 0, "After clearing search")

        vm.searchText = "tett"; vm.search(); applyHighlight()
        XCTAssertEqual(hlCount(), 0, "After 'tett'")
        XCTAssertEqual(vm.searchResults.count, 0)
    }

    // MARK: - SearchHighlightTextView Overlay Tests

    private func makeSearchHighlightTextView(content: String) -> SearchHighlightTextView {
        let textStorage = NSTextStorage(string: content)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 200, height: 200))
        layoutManager.addTextContainer(textContainer)
        let textView = SearchHighlightTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), textContainer: textContainer)
        return textView
    }

    func testSearchHighlightTextView_SetHighlightRange() {
        let textView = makeSearchHighlightTextView(content: "Test")

        XCTAssertNil(textView.highlightRange, "Should start with no highlight")

        textView.highlightRange = NSRange(location: 0, length: 4)
        XCTAssertEqual(textView.highlightRange, NSRange(location: 0, length: 4))

        textView.highlightRange = nil
        XCTAssertNil(textView.highlightRange, "Should clear to nil")
    }

    func testSearchHighlightTextView_FullSearchFlow() {
        let content = "Test"
        let textView = makeSearchHighlightTextView(content: content)

        highlightViewModel = FileEditorViewModel(
            filePath: "/test.txt",
            fileName: "test.txt",
            initialContent: content,
            fileRepository: MockFileRepository()
        )
        let vm = highlightViewModel!

        func applyHighlight() {
            let shouldHighlight = !vm.searchText.isEmpty && !vm.searchResults.isEmpty && vm.currentSearchIndex < vm.searchResults.count
            if shouldHighlight {
                let stringRange = vm.searchResults[vm.currentSearchIndex]
                textView.highlightRange = NSRange(stringRange, in: vm.content)
            } else {
                textView.highlightRange = nil
            }
        }

        vm.searchText = "t"; vm.search(); applyHighlight()
        XCTAssertNotNil(textView.highlightRange, "After 't' — should have highlight")
        XCTAssertEqual(textView.highlightRange!.length, 1)

        vm.searchText = "te"; vm.search(); applyHighlight()
        XCTAssertNotNil(textView.highlightRange, "After 'te' — should have highlight")
        XCTAssertEqual(textView.highlightRange!.length, 2)

        vm.searchText = "tes"; vm.search(); applyHighlight()
        XCTAssertNotNil(textView.highlightRange, "After 'tes'")
        XCTAssertEqual(textView.highlightRange!.length, 3)

        vm.searchText = "test"; vm.search(); applyHighlight()
        XCTAssertNotNil(textView.highlightRange, "After 'test'")
        XCTAssertEqual(textView.highlightRange!.length, 4)

        vm.searchText = "tes"; vm.search(); applyHighlight()
        XCTAssertNotNil(textView.highlightRange, "After backspace to 'tes'")
        XCTAssertEqual(textView.highlightRange!.length, 3)

        vm.searchText = ""; vm.search(); applyHighlight()
        XCTAssertNil(textView.highlightRange, "After clearing search — should be nil")

        vm.searchText = "tett"; vm.search(); applyHighlight()
        XCTAssertNil(textView.highlightRange, "After 'tett' — no match, should be nil")
    }

    func testSearchHighlightViewModel_IntegrationWithOverlay() {
        let content = "Hello Test Testing tested"
        let textView = makeSearchHighlightTextView(content: content)

        highlightViewModel = FileEditorViewModel(
            filePath: "/test.txt",
            fileName: "test.txt",
            initialContent: content,
            fileRepository: MockFileRepository()
        )
        let vm = highlightViewModel!

        func applyHighlight() {
            let shouldHighlight = !vm.searchText.isEmpty && !vm.searchResults.isEmpty && vm.currentSearchIndex < vm.searchResults.count
            if shouldHighlight {
                let stringRange = vm.searchResults[vm.currentSearchIndex]
                textView.highlightRange = NSRange(stringRange, in: vm.content)
            } else {
                textView.highlightRange = nil
            }
        }

        let queries = ["t", "te", "tes", "test", "testi", "", "test", "tett"]
        for query in queries {
            vm.searchText = query
            vm.search()
            applyHighlight()

            if query.isEmpty || query == "tett" {
                XCTAssertNil(textView.highlightRange, "Query '\(query)' should have no highlight")
            } else {
                XCTAssertNotNil(textView.highlightRange, "Query '\(query)' should have highlight")
                let matchedContent = String(content[vm.searchResults[vm.currentSearchIndex]])
                XCTAssertEqual(matchedContent.lowercased().hasPrefix(query.lowercased()), true)
            }
        }
    }

    func testSearchHighlightViewModel_ClearsOnEmptySearch() {
        let content = "Test"
        let textView = makeSearchHighlightTextView(content: content)

        highlightViewModel = FileEditorViewModel(
            filePath: "/test.txt",
            fileName: "test.txt",
            initialContent: content,
            fileRepository: MockFileRepository()
        )
        let vm = highlightViewModel!

        vm.searchText = "test"; vm.search()
        let stringRange = vm.searchResults[vm.currentSearchIndex]
        textView.highlightRange = NSRange(stringRange, in: vm.content)
        XCTAssertNotNil(textView.highlightRange)

        vm.searchText = ""; vm.search()
        textView.highlightRange = nil
        XCTAssertNil(textView.highlightRange, "Empty search must clear highlight")
    }

    func testSearchHighlightViewModel_ClearsOnNonMatch() {
        let content = "Test"
        let textView = makeSearchHighlightTextView(content: content)

        highlightViewModel = FileEditorViewModel(
            filePath: "/test.txt",
            fileName: "test.txt",
            initialContent: content,
            fileRepository: MockFileRepository()
        )
        let vm = highlightViewModel!

        vm.searchText = "test"; vm.search()
        let stringRange = vm.searchResults[vm.currentSearchIndex]
        textView.highlightRange = NSRange(stringRange, in: vm.content)
        XCTAssertNotNil(textView.highlightRange)

        vm.searchText = "tett"; vm.search()
        XCTAssertTrue(vm.searchResults.isEmpty)
        textView.highlightRange = nil
        XCTAssertNil(textView.highlightRange, "Non-matching search must clear highlight")
    }
}
