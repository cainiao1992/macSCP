//
//  ClipboardServiceProtocol.swift
//  macSCP
//
//  Protocol for clipboard service abstraction
//

import Foundation

@MainActor
protocol ClipboardServiceProtocol: Sendable {
    var state: ClipboardState { get }
    func copy(files: [RemoteFile], from sourcePath: String, connectionId: UUID)
    func cut(files: [RemoteFile], from sourcePath: String, connectionId: UUID)
    func clear()
    var isEmpty: Bool { get }
    var isCopy: Bool { get }
    var isCut: Bool { get }
    var items: [ClipboardItem] { get }
    var fileCount: Int { get }
    var displayText: String { get }
    var connectionId: UUID? { get }
    func canPaste(to connectionId: UUID) -> Bool
}
