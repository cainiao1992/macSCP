//
//  RemoteClipboard.swift
//  macSCP
//
//  Clipboard manager for remote file operations (copy/cut/paste)
//

import Foundation
import Combine
import SwiftUI

enum ClipboardOperation {
    case copy
    case cut
}

struct ClipboardItem {
    let file: RemoteFile
    let operation: ClipboardOperation
    let sourcePath: String // Track the directory where the file was copied/cut from
}

@MainActor
class RemoteClipboard: ObservableObject {
    static let shared = RemoteClipboard()

    @Published var items: [ClipboardItem] = []
    @Published var operation: ClipboardOperation?

    private init() {}

    func copy(files: [RemoteFile], from sourcePath: String) {
        items = files.map { ClipboardItem(file: $0, operation: .copy, sourcePath: sourcePath) }
        operation = .copy
    }

    func cut(files: [RemoteFile], from sourcePath: String) {
        items = files.map { ClipboardItem(file: $0, operation: .cut, sourcePath: sourcePath) }
        operation = .cut
    }

    func clear() {
        items = []
        operation = nil
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    var isCopy: Bool {
        operation == .copy
    }

    var isCut: Bool {
        operation == .cut
    }

    var fileCount: Int {
        items.count
    }

    var displayText: String {
        if isEmpty {
            return "Clipboard empty"
        }
        let opText = isCopy ? "Copied" : "Cut"
        if items.count == 1 {
            return "\(opText): \(items[0].file.name)"
        } else {
            return "\(opText): \(items.count) items"
        }
    }
}
