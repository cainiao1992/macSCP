//
//  MockWindowManager.swift
//  macSCPTests
//
//  Mock implementation of WindowManagerProtocol for testing
//

import Foundation
@testable import macSCP

@MainActor
final class MockWindowManager: WindowManagerProtocol {
    // MARK: - In-Memory Storage
    private var fileBrowserData: [String: FileBrowserWindowData] = [:]
    private var fileEditorData: [String: FileEditorWindowData] = [:]
    private var fileInfoData: [String: FileInfoWindowData] = [:]

    // MARK: - Recorded Calls
    var storeFileBrowserDataCalled = false
    var storeFileEditorDataCalled = false
    var storeFileInfoDataCalled = false
    var clearAllDataCalled = false

    // MARK: - File Browser Window

    func storeFileBrowserData(_ data: FileBrowserWindowData) -> String {
        storeFileBrowserDataCalled = true
        let id = UUID().uuidString
        fileBrowserData[id] = data
        return id
    }

    func getFileBrowserData(for id: String) -> FileBrowserWindowData? {
        fileBrowserData[id]
    }

    func removeFileBrowserData(for id: String) {
        fileBrowserData.removeValue(forKey: id)
    }

    // MARK: - File Editor Window

    func storeFileEditorData(_ data: FileEditorWindowData) -> String {
        storeFileEditorDataCalled = true
        let id = UUID().uuidString
        fileEditorData[id] = data
        return id
    }

    func getFileEditorData(for id: String) -> FileEditorWindowData? {
        fileEditorData[id]
    }

    func removeFileEditorData(for id: String) {
        fileEditorData.removeValue(forKey: id)
    }

    // MARK: - File Info Window

    func storeFileInfoData(_ data: FileInfoWindowData) -> String {
        storeFileInfoDataCalled = true
        let id = UUID().uuidString
        fileInfoData[id] = data
        return id
    }

    func getFileInfoData(for id: String) -> FileInfoWindowData? {
        fileInfoData[id]
    }

    func removeFileInfoData(for id: String) {
        fileInfoData.removeValue(forKey: id)
    }

    // MARK: - Cleanup

    func clearAllData() {
        clearAllDataCalled = true
        fileBrowserData.removeAll()
        fileEditorData.removeAll()
        fileInfoData.removeAll()
    }
}
