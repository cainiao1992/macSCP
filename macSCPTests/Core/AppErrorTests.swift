//
//  AppErrorTests.swift
//  macSCPTests
//
//  Unit tests for AppError enum
//

import XCTest
@testable import macSCP

@MainActor
final class AppErrorTests: XCTestCase {

    // MARK: - errorDescription: Connection Errors

    func testErrorDescription_ConnectionFailed() {
        let error = AppError.connectionFailed("timeout")
        XCTAssertTrue(error.errorDescription?.contains("Connection failed: timeout") ?? false)
    }

    func testErrorDescription_ConnectionTimeout() {
        XCTAssertEqual(AppError.connectionTimeout.errorDescription, "Connection timed out")
    }

    func testErrorDescription_ConnectionLost() {
        XCTAssertEqual(AppError.connectionLost.errorDescription, "Connection was lost")
    }

    func testErrorDescription_AuthenticationFailed() {
        let desc = AppError.authenticationFailed.errorDescription
        XCTAssertTrue(desc?.contains("Authentication failed") ?? false)
    }

    func testErrorDescription_HostUnreachable() {
        let desc = AppError.hostUnreachable.errorDescription
        XCTAssertTrue(desc?.contains("unreachable") ?? false)
    }

    // MARK: - errorDescription: SFTP Errors

    func testErrorDescription_SftpOperationFailed() {
        let error = AppError.sftpOperationFailed("read error")
        XCTAssertEqual(error.errorDescription, "SFTP operation failed: read error")
    }

    func testErrorDescription_PermissionDenied() {
        XCTAssertEqual(AppError.permissionDenied.errorDescription, "Permission denied")
    }

    func testErrorDescription_FileNotFound() {
        XCTAssertEqual(AppError.fileNotFound.errorDescription, "File or directory not found")
    }

    func testErrorDescription_FileAlreadyExists() {
        let desc = AppError.fileAlreadyExists.errorDescription
        XCTAssertTrue(desc?.contains("already exists") ?? false)
    }

    func testErrorDescription_DirectoryNotEmpty() {
        let desc = AppError.directoryNotEmpty.errorDescription
        XCTAssertTrue(desc?.contains("not empty") ?? false)
    }

    func testErrorDescription_InvalidPath() {
        XCTAssertEqual(AppError.invalidPath.errorDescription, "Invalid path")
    }

    // MARK: - errorDescription: S3 Errors

    func testErrorDescription_S3BucketNotFound() {
        let desc = AppError.s3BucketNotFound.errorDescription
        XCTAssertTrue(desc?.contains("bucket not found") ?? false)
    }

    func testErrorDescription_S3AccessDenied() {
        let desc = AppError.s3AccessDenied.errorDescription
        XCTAssertTrue(desc?.contains("Access denied") ?? false)
    }

    func testErrorDescription_S3ObjectNotFound() {
        let desc = AppError.s3ObjectNotFound.errorDescription
        XCTAssertTrue(desc?.contains("object not found") ?? false)
    }

    func testErrorDescription_S3OperationFailed() {
        let error = AppError.s3OperationFailed("access")
        XCTAssertEqual(error.errorDescription, "S3 operation failed: access")
    }

    func testErrorDescription_InvalidS3Credentials() {
        XCTAssertEqual(AppError.invalidS3Credentials.errorDescription, "Invalid S3 credentials")
    }

    // MARK: - errorDescription: Data Errors

    func testErrorDescription_SaveFailed() {
        let error = AppError.saveFailed("disk")
        XCTAssertEqual(error.errorDescription, "Failed to save: disk")
    }

    func testErrorDescription_FetchFailed() {
        let error = AppError.fetchFailed("query")
        XCTAssertEqual(error.errorDescription, "Failed to fetch: query")
    }

    func testErrorDescription_DeleteFailed() {
        let error = AppError.deleteFailed("ref")
        XCTAssertEqual(error.errorDescription, "Failed to delete: ref")
    }

    func testErrorDescription_EntityNotFound() {
        XCTAssertEqual(AppError.entityNotFound.errorDescription, "Entity not found")
    }

    // MARK: - errorDescription: Keychain Errors

    func testErrorDescription_KeychainSaveFailed() {
        let desc = AppError.keychainSaveFailed.errorDescription
        XCTAssertTrue(desc?.contains("keychain") ?? false)
    }

    func testErrorDescription_KeychainReadFailed() {
        let desc = AppError.keychainReadFailed.errorDescription
        XCTAssertTrue(desc?.contains("keychain") ?? false)
    }

    func testErrorDescription_KeychainDeleteFailed() {
        let desc = AppError.keychainDeleteFailed.errorDescription
        XCTAssertTrue(desc?.contains("keychain") ?? false)
    }

    // MARK: - errorDescription: File Operation Errors

    func testErrorDescription_DownloadFailed() {
        let error = AppError.downloadFailed("network")
        XCTAssertEqual(error.errorDescription, "Download failed: network")
    }

    func testErrorDescription_UploadFailed() {
        let error = AppError.uploadFailed("disk")
        XCTAssertEqual(error.errorDescription, "Upload failed: disk")
    }

    func testErrorDescription_FileReadFailed() {
        XCTAssertEqual(AppError.fileReadFailed.errorDescription, "Failed to read file")
    }

    func testErrorDescription_FileWriteFailed() {
        XCTAssertEqual(AppError.fileWriteFailed.errorDescription, "Failed to write file")
    }

    // MARK: - errorDescription: Terminal Errors

    func testErrorDescription_TerminalConnectionFailed() {
        let error = AppError.terminalConnectionFailed("refused")
        XCTAssertEqual(error.errorDescription, "Terminal connection failed: refused")
    }

    func testErrorDescription_TerminalConnectionLost() {
        XCTAssertEqual(AppError.terminalConnectionLost.errorDescription, "Terminal connection was lost")
    }

    func testErrorDescription_TerminalPTYFailed() {
        let desc = AppError.terminalPTYFailed.errorDescription
        XCTAssertTrue(desc?.contains("pseudo-terminal") ?? false)
    }

    // MARK: - errorDescription: Biometric Errors

    func testErrorDescription_BiometricNotAvailable() {
        let desc = AppError.biometricNotAvailable.errorDescription
        XCTAssertTrue(desc?.contains("Touch ID") ?? false)
    }

    func testErrorDescription_BiometricAuthFailed() {
        let error = AppError.biometricAuthFailed("cancel")
        let desc = error.errorDescription
        XCTAssertTrue(desc?.contains("cancel") ?? false)
    }

    // MARK: - errorDescription: General Errors

    func testErrorDescription_Unknown() {
        let error = AppError.unknown("custom")
        XCTAssertEqual(error.errorDescription, "custom")
    }

    func testErrorDescription_NotConnected() {
        let desc = AppError.notConnected.errorDescription
        XCTAssertTrue(desc?.contains("Not connected") ?? false)
    }

    // MARK: - recoverySuggestion

    func testRecoverySuggestion_ConnectionFailed() {
        let desc = AppError.connectionFailed("test").recoverySuggestion
        XCTAssertTrue(desc?.contains("network connection") ?? false)
    }

    func testRecoverySuggestion_AuthenticationFailed() {
        let desc = AppError.authenticationFailed.recoverySuggestion
        XCTAssertTrue(desc?.contains("verify your username and password") ?? false)
    }

    func testRecoverySuggestion_PermissionDenied() {
        let desc = AppError.permissionDenied.recoverySuggestion
        XCTAssertTrue(desc?.contains("don't have permission") ?? false)
    }

    func testRecoverySuggestion_NotConnected() {
        let desc = AppError.notConnected.recoverySuggestion
        XCTAssertTrue(desc?.contains("connect to a server first") ?? false)
    }

    func testRecoverySuggestion_S3BucketNotFound() {
        let desc = AppError.s3BucketNotFound.recoverySuggestion
        XCTAssertTrue(desc?.contains("bucket name") ?? false)
    }

    func testRecoverySuggestion_InvalidS3Credentials() {
        let desc = AppError.invalidS3Credentials.recoverySuggestion
        XCTAssertTrue(desc?.contains("Access Key ID") ?? false)
    }

    func testRecoverySuggestion_TerminalConnectionFailed() {
        let desc = AppError.terminalConnectionFailed("test").recoverySuggestion
        XCTAssertTrue(desc?.contains("network connection") ?? false)
    }

    func testRecoverySuggestion_TerminalPTYFailed() {
        let desc = AppError.terminalPTYFailed.recoverySuggestion
        XCTAssertTrue(desc?.contains("interactive terminals") ?? false)
    }

    func testRecoverySuggestion_BiometricNotAvailable() {
        let desc = AppError.biometricNotAvailable.recoverySuggestion
        XCTAssertTrue(desc?.contains("Touch ID") ?? false)
    }

    func testRecoverySuggestion_BiometricAuthFailed() {
        let desc = AppError.biometricAuthFailed("test").recoverySuggestion
        XCTAssertTrue(desc?.contains("try again") ?? false)
    }

    func testRecoverySuggestion_SftpOperationFailed_Nil() {
        XCTAssertNil(AppError.sftpOperationFailed("test").recoverySuggestion)
    }

    func testRecoverySuggestion_FileNotFound_Nil() {
        XCTAssertNil(AppError.fileNotFound.recoverySuggestion)
    }

    func testRecoverySuggestion_Unknown_Nil() {
        XCTAssertNil(AppError.unknown("test").recoverySuggestion)
    }

    // MARK: - AppError.from()

    func testFrom_AppError() {
        let original = AppError.connectionFailed("test")
        let converted = AppError.from(original as Error)
        if case .connectionFailed("test") = converted {
        } else {
            XCTFail("Expected .connectionFailed(\"test\")")
        }
    }

    func testFrom_NonAppError() {
        struct CustomError: Error {}
        let error = CustomError()
        let converted = AppError.from(error)
        if case .unknown(let message) = converted {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected .unknown case")
        }
    }

    func testFrom_NSError() {
        let nsError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "ns error"])
        let converted = AppError.from(nsError)
        if case .unknown(let message) = converted {
            XCTAssertEqual(message, "ns error")
        } else {
            XCTFail("Expected .unknown case")
        }
    }
}
