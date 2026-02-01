//
//  AnalyticsService.swift
//  macSCP
//
//  Privacy-focused analytics using TelemetryDeck
//

import Foundation
import TelemetryClient

enum AnalyticsService {
    // MARK: - Configuration

    static func initialize() {
        let config = TelemetryManagerConfiguration(appID: "B5BEE195-393B-4B84-8B10-0BEC90496251")
        TelemetryManager.initialize(with: config)

        // Track app launch
        track(.appLaunched)
    }

    // MARK: - Track Events

    static func track(_ event: Event) {
        TelemetryManager.send(event.rawValue)
    }

    static func track(_ event: Event, with parameters: [String: String]) {
        TelemetryManager.send(event.rawValue, with: parameters)
    }

    // MARK: - Events

    enum Event: String {
        // App lifecycle
        case appLaunched = "app_launched"

        // Connections
        case connectionCreated = "connection_created"
        case connectionEdited = "connection_edited"
        case connectionDeleted = "connection_deleted"
        case connectionConnected = "connection_connected"

        // Folders
        case folderCreated = "folder_created"
        case folderDeleted = "folder_deleted"

        // File browser
        case fileBrowserOpened = "file_browser_opened"
        case fileUploaded = "file_uploaded"
        case fileDownloaded = "file_downloaded"
        case fileDeleted = "file_deleted"
        case fileRenamed = "file_renamed"
        case folderCreatedRemote = "folder_created_remote"

        // Editor
        case editorOpened = "editor_opened"
        case fileSaved = "file_saved"

        // File info
        case fileInfoOpened = "file_info_opened"
    }
}
