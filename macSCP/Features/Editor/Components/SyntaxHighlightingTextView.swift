//
//  SyntaxHighlightingTextView.swift
//  macSCP
//
//  NSViewRepresentable wrapping NSTextView with Highlightr syntax highlighting
//  Based on official Highlightr_OSX_Example/AppDelegate.swift
//

import AppKit
@preconcurrency import Highlightr
import SwiftUI

extension Notification.Name {
    static let editorSearchStateChanged = Notification.Name("editorSearchStateChanged")
}

// MARK: - SearchHighlightTextView

final class SearchHighlightTextView: NSTextView {
    var highlightRange: NSRange?

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let highlightRange, let layoutManager = layoutManager, let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: highlightRange, actualCharacterRange: nil)
        let highlightColor = NSColor.systemYellow.withAlphaComponent(0.4)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, lineRect, _, lineGlyphRange, _ in
            let intersectGlyphRange = NSIntersectionRange(glyphRange, lineGlyphRange)
            guard intersectGlyphRange.length > 0 else { return }

            let rect = layoutManager.boundingRect(forGlyphRange: intersectGlyphRange, in: textContainer)
            let inset = self.textContainerInset
            let drawRect = NSRect(
                x: rect.origin.x + inset.width,
                y: lineRect.origin.y + inset.height,
                width: rect.width,
                height: lineRect.height
            )

            highlightColor.setFill()
            NSBezierPath(roundedRect: drawRect.insetBy(dx: -1, dy: 0), xRadius: 2, yRadius: 2).fill()
        }
    }
}

// MARK: - SyntaxHighlightingTextView

struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Bindable var viewModel: FileEditorViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = CodeAttributedString()
        textStorage.language = LanguageDetectionService.language(for: viewModel.fileName)
        let themeName = EditorThemeService.themeName(for: NSApp.effectiveAppearance)
        textStorage.highlightr.setTheme(to: themeName)
        textStorage.highlightr.theme.setCodeFont(
            NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        )

        textStorage.setAttributedString(NSAttributedString(string: viewModel.content))

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)

        let textView = SearchHighlightTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 10000), textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.autoresizingMask = [.width, .height]
        textView.translatesAutoresizingMaskIntoConstraints = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.backgroundColor = textStorage.highlightr.theme.themeBackgroundColor ?? .windowBackgroundColor
        textView.insertionPointColor = EditorThemeService.insertionPointColor(for: NSApp.effectiveAppearance)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 4)

        context.coordinator.textView = textView
        context.coordinator.textStorage = textStorage
        context.coordinator.startObservingAppearance(textView: textView, textStorage: textStorage)
        context.coordinator.startObservingSearchState()

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]
        scrollView.backgroundColor = textStorage.highlightr.theme.themeBackgroundColor ?? .windowBackgroundColor

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.viewModel = viewModel

        if let pending = viewModel.pendingSingleReplace {
            viewModel.pendingSingleReplace = nil
            let nsRange = NSRange(pending.range, in: viewModel.content)
            textView.insertText(NSAttributedString(string: pending.text), replacementRange: nsRange)
            let coordinator = context.coordinator
            DispatchQueue.main.async {
                coordinator.viewModel.search()
            }
            return
        }

        if let replacements = viewModel.pendingReplaceAll, !replacements.isEmpty {
            viewModel.pendingReplaceAll = nil
            for (range, text) in replacements.reversed() {
                let nsRange = NSRange(range, in: viewModel.content)
                textView.insertText(NSAttributedString(string: text), replacementRange: nsRange)
            }
            let coordinator = context.coordinator
            DispatchQueue.main.async {
                coordinator.viewModel.search()
            }
            return
        }

        if textView.string != viewModel.content {
            textView.string = viewModel.content
        }

        let newLanguage = LanguageDetectionService.language(for: viewModel.fileName)
        if context.coordinator.textStorage?.language != newLanguage {
            context.coordinator.textStorage?.language = newLanguage
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var viewModel: FileEditorViewModel
        weak var textView: NSTextView?
        var textStorage: CodeAttributedString?
        private var appearanceObservation: NSKeyValueObservation?
        private var searchObserver: NSObjectProtocol?

        init(viewModel: FileEditorViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            appearanceObservation?.invalidate()
            if let observer = searchObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.viewModel.content != newText {
                    self.viewModel.content = newText
                }
            }
        }

        // MARK: - Search Highlight

        func updateSearchHighlight(textView: NSTextView) {
            guard let highlightTextView = textView as? SearchHighlightTextView else { return }

            let shouldHighlight = viewModel.isShowingSearch
                && !viewModel.searchText.isEmpty
                && !viewModel.searchResults.isEmpty
                && viewModel.currentSearchIndex < viewModel.searchResults.count

            if shouldHighlight {
                let stringRange = viewModel.searchResults[viewModel.currentSearchIndex]
                let nsRange = NSRange(stringRange, in: viewModel.content)
                highlightTextView.highlightRange = nsRange
                textView.setSelectedRange(nsRange)
                textView.scrollRangeToVisible(nsRange)
            } else {
                highlightTextView.highlightRange = nil
                textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0))
            }

            highlightTextView.needsDisplay = true
        }

        // MARK: - Search State Observation

        func startObservingSearchState() {
            searchObserver = NotificationCenter.default.addObserver(
                forName: .editorSearchStateChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let textView = self.textView else { return }
                    self.updateSearchHighlight(textView: textView)
                }
            }
        }

        // MARK: - Appearance Observation

        func startObservingAppearance(textView: NSTextView, textStorage: CodeAttributedString) {
            appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let appearance = NSApplication.shared.effectiveAppearance
                    self.applyTheme(for: appearance, textStorage: self.textStorage ?? textStorage)
                }
            }
        }

        private func applyTheme(for appearance: NSAppearance, textStorage: CodeAttributedString) {
            guard let textView else { return }

            let themeName = EditorThemeService.themeName(for: appearance)
            textStorage.highlightr.setTheme(to: themeName)
            textStorage.highlightr.theme.setCodeFont(
                NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            )

            let lang = textStorage.language
            textStorage.language = nil
            textStorage.language = lang

            let bgColor = textStorage.highlightr.theme.themeBackgroundColor ?? .windowBackgroundColor
            textView.backgroundColor = bgColor
            textView.enclosingScrollView?.backgroundColor = bgColor

            textView.insertionPointColor = EditorThemeService.insertionPointColor(for: appearance)
        }
    }
}
