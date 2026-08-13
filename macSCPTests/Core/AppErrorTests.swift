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

    func testRecoverySuggestion_SftpOperationFailed() {
        let desc = AppError.sftpOperationFailed("test").recoverySuggestion
        XCTAssertTrue(desc?.contains("file exists") ?? false)
    }

    func testRecoverySuggestion_FileNotFound() {
        let desc = AppError.fileNotFound.recoverySuggestion
        XCTAssertTrue(desc?.contains("moved or deleted") ?? false)
    }

    func testRecoverySuggestion_Unknown() {
        let desc = AppError.unknown("test").recoverySuggestion
        XCTAssertTrue(desc?.contains("retry") ?? false)
    }

    // MARK: - errorDescription: Host Key Mismatch

    func testErrorDescription_HostKeyMismatch() {
        let error = AppError.hostKeyMismatch(host: "example.com", port: 22)
        let desc = error.errorDescription
        XCTAssertTrue(desc?.contains("example.com") ?? false)
        XCTAssertTrue(desc?.contains("22") ?? false)
        XCTAssertTrue(desc?.contains("host key") ?? false)
    }

    func testErrorDescription_HostKeyMismatch_NonStandardPort() {
        let error = AppError.hostKeyMismatch(host: "10.0.0.1", port: 2222)
        let desc = error.errorDescription
        XCTAssertTrue(desc?.contains("10.0.0.1") ?? false)
        XCTAssertTrue(desc?.contains("2222") ?? false)
    }

    // MARK: - recoverySuggestion: Host Key Mismatch

    func testRecoverySuggestion_HostKeyMismatch() {
        let error = AppError.hostKeyMismatch(host: "example.com", port: 22)
        let desc = error.recoverySuggestion
        XCTAssertTrue(desc?.contains("replace") ?? false)
        XCTAssertTrue(desc?.contains("disconnect") ?? false)
    }

    // MARK: - isHostKeyMismatch

    func testIsHostKeyMismatch_True() {
        let error = AppError.hostKeyMismatch(host: "example.com", port: 22)
        XCTAssertTrue(error.isHostKeyMismatch)
    }

    func testIsHostKeyMismatch_False() {
        let error = AppError.connectionFailed("test")
        XCTAssertFalse(error.isHostKeyMismatch)
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

    // MARK: - from(_:): URLError mapping

    func testFrom_URLErrorTimedOutMapsToConnectionTimeout() {
        let error = URLError(.timedOut)
        let result = AppError.from(error)
        guard case .connectionTimeout = result else {
            return XCTFail("Expected connectionTimeout")
        }
    }

    func testFrom_URLErrorNotConnectedMapsToConnectionLost() {
        let error = URLError(.notConnectedToInternet)
        let result = AppError.from(error)
        guard case .connectionLost = result else {
            return XCTFail("Expected connectionLost")
        }
    }

    func testFrom_URLErrorCannotConnectMapsToHostUnreachable() {
        let error = URLError(.cannotConnectToHost)
        let result = AppError.from(error)
        guard case .hostUnreachable = result else {
            return XCTFail("Expected hostUnreachable")
        }
    }

    func testFrom_URLErrorUnknownMapsToConnectionFailed() {
        let error = URLError(.badServerResponse)
        let result = AppError.from(error)
        guard case .connectionFailed = result else {
            return XCTFail("Expected connectionFailed")
        }
    }

    // MARK: - from(_:): Keychain OSStatus mapping

    func testFrom_KeychainItemNotFoundMapsToEntityNotFound() {
        let error = NSError(domain: "com.apple.security", code: -25300)
        let result = AppError.from(error)
        guard case .entityNotFound = result else {
            return XCTFail("Expected entityNotFound")
        }
    }

    func testFrom_KeychainUserCanceledMapsToCancelledUnknown() {
        let error = NSError(domain: "com.apple.security", code: -128)
        let result = AppError.from(error)
        guard case .unknown(let message) = result else {
            return XCTFail("Expected unknown")
        }
        XCTAssertEqual(message, "Operation cancelled")
    }

    func testFrom_KeychainOtherStatusMapsToKeychainReadFailed() {
        let error = NSError(domain: "com.apple.security", code: -25293)
        let result = AppError.from(error)
        guard case .keychainReadFailed = result else {
            return XCTFail("Expected keychainReadFailed")
        }
    }

    // MARK: - from(_:): NIO / SSH domain mapping

    func testFrom_NIOErrorMapsToSftpOperationFailed() {
        let error = NSError(domain: "NIOSSH", code: 1, userInfo: [NSLocalizedDescriptionKey: "handshake failed"])
        let result = AppError.from(error)
        guard case .sftpOperationFailed = result else {
            return XCTFail("Expected sftpOperationFailed")
        }
    }

    func testFrom_LibsshErrorMapsToSftpOperationFailed() {
        let error = NSError(domain: "libssh", code: 1, userInfo: [NSLocalizedDescriptionKey: "auth failed"])
        let result = AppError.from(error)
        guard case .sftpOperationFailed = result else {
            return XCTFail("Expected sftpOperationFailed")
        }
    }
}
