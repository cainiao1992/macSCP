//
//  AnalyticsServiceTests.swift
//  macSCPTests
//
//  Unit tests for AnalyticsService enums and raw values
//

import XCTest
@testable import macSCP

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    // MARK: - Event Raw Values: App Lifecycle

    func testEventAppLaunchedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.appLaunched.rawValue, "app_launched")
    }

    // MARK: - Event Raw Values: Connections

    func testEventConnectionCreatedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.connectionCreated.rawValue, "connection_created")
    }

    func testEventConnectionEditedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.connectionEdited.rawValue, "connection_edited")
    }

    func testEventConnectionDeletedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.connectionDeleted.rawValue, "connection_deleted")
    }

    func testEventConnectionConnectedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.connectionConnected.rawValue, "connection_connected")
    }

    func testEventConnectionFailedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.connectionFailed.rawValue, "connection_failed")
    }

    // MARK: - Event Raw Values: Folders

    func testEventFolderCreatedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.folderCreated.rawValue, "folder_created")
    }

    func testEventFolderDeletedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.folderDeleted.rawValue, "folder_deleted")
    }

    // MARK: - Event Raw Values: File Browser

    func testEventFileBrowserOpenedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileBrowserOpened.rawValue, "file_browser_opened")
    }

    func testEventFileUploadedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileUploaded.rawValue, "file_uploaded")
    }

    func testEventFileDownloadedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileDownloaded.rawValue, "file_downloaded")
    }

    func testEventFileDeletedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileDeleted.rawValue, "file_deleted")
    }

    func testEventFileRenamedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileRenamed.rawValue, "file_renamed")
    }

    // MARK: - Event Raw Values: Editor

    func testEventEditorOpenedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.editorOpened.rawValue, "editor_opened")
    }

    func testEventFileSavedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileSaved.rawValue, "file_saved")
    }

    // MARK: - Event Raw Values: File Info

    func testEventFileInfoOpenedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.fileInfoOpened.rawValue, "file_info_opened")
    }

    // MARK: - Event Raw Values: Biometric

    func testEventBiometricEnabledRawValue() {
        XCTAssertEqual(AnalyticsService.Event.biometricEnabled.rawValue, "biometric_enabled")
    }

    func testEventBiometricDisabledRawValue() {
        XCTAssertEqual(AnalyticsService.Event.biometricDisabled.rawValue, "biometric_disabled")
    }

    func testEventBiometricSuccessRawValue() {
        XCTAssertEqual(AnalyticsService.Event.biometricSuccess.rawValue, "biometric_success")
    }

    func testEventBiometricFailedRawValue() {
        XCTAssertEqual(AnalyticsService.Event.biometricFailed.rawValue, "biometric_failed")
    }

    // MARK: - ConnectionProtocol Tests

    func testConnectionProtocolSftpRawValue() {
        XCTAssertEqual(AnalyticsService.ConnectionProtocol.sftp.rawValue, "sftp")
    }

    func testConnectionProtocolS3RawValue() {
        XCTAssertEqual(AnalyticsService.ConnectionProtocol.s3.rawValue, "s3")
    }

    func testConnectionProtocolFromSftp() {
        let protocol_ = AnalyticsService.ConnectionProtocol(from: .sftp)
        XCTAssertEqual(protocol_, .sftp)
    }

    func testConnectionProtocolFromS3() {
        let protocol_ = AnalyticsService.ConnectionProtocol(from: .s3)
        XCTAssertEqual(protocol_, .s3)
    }

    // MARK: - FileOperation Tests

    func testFileOperationDeleteExists() {
        // Verify .delete case compiles and is a valid case
        let operation = AnalyticsService.FileOperation.delete
        switch operation {
        case .delete:
            // expected
            break
        case .rename, .createFolder:
            XCTFail("Expected .delete case")
        }
    }

    func testFileOperationRenameExists() {
        let operation = AnalyticsService.FileOperation.rename
        switch operation {
        case .rename:
            break
        case .delete, .createFolder:
            XCTFail("Expected .rename case")
        }
    }

    func testFileOperationCreateFolderExists() {
        let operation = AnalyticsService.FileOperation.createFolder
        switch operation {
        case .createFolder:
            break
        case .delete, .rename:
            XCTFail("Expected .createFolder case")
        }
    }

    // MARK: - Event Enum Completeness

    func testEventEnumCaseCount() {
        // Count all cases to verify completeness
        let allEvents: [AnalyticsService.Event] = [
            .appLaunched,
            .connectionCreated,
            .connectionEdited,
            .connectionDeleted,
            .connectionConnected,
            .connectionFailed,
            .folderCreated,
            .folderDeleted,
            .fileBrowserOpened,
            .fileUploaded,
            .fileDownloaded,
            .fileDeleted,
            .fileRenamed,
            .folderCreatedRemote,
            .transferFailed,
            .editorOpened,
            .fileSaved,
            .fileInfoOpened,
            .biometricEnabled,
            .biometricDisabled,
            .biometricSuccess,
            .biometricFailed
        ]
        XCTAssertEqual(allEvents.count, 22, "All expected Event cases should be present")
    }
}
