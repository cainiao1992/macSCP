//
//  WindowManagerProtocol.swift
//  macSCP
//
//  Protocol for window data management in multi-window support
//

import Foundation

@MainActor
protocol WindowManagerProtocol: AnyObject {
    // MARK: - File Browser Window
    func storeFileBrowserData(_ data: FileBrowserWindowData) -> String
    func getFileBrowserData(for id: String) -> FileBrowserWindowData?
    func removeFileBrowserData(for id: String)

    // MARK: - File Editor Window
    func storeFileEditorData(_ data: FileEditorWindowData) -> String
    func getFileEditorData(for id: String) -> FileEditorWindowData?
    func removeFileEditorData(for id: String)

    // MARK: - File Info Window
    func storeFileInfoData(_ data: FileInfoWindowData) -> String
    func getFileInfoData(for id: String) -> FileInfoWindowData?
    func removeFileInfoData(for id: String)

    // MARK: - Cleanup
    func clearAllData()
}
