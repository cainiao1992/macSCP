//
//  AppError.swift
//  macSCP
//
//  Unified error types for the application
//

import Foundation

enum AppError: LocalizedError, Sendable {
    // Connection errors
    case connectionFailed(String)
    case connectionTimeout
    case connectionLost
    case authenticationFailed
    case hostUnreachable
    case hostKeyMismatch(host: String, port: Int)

    // SFTP errors
    case sftpOperationFailed(String)
    case permissionDenied
    case fileNotFound
    case fileAlreadyExists
    case directoryNotEmpty
    case invalidPath

    // S3 errors
    case s3BucketNotFound
    case s3AccessDenied
    case s3ObjectNotFound
    case s3OperationFailed(String)
    case invalidS3Credentials

    // Data errors
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case entityNotFound

    // Keychain errors
    case keychainSaveFailed
    case keychainReadFailed
    case keychainDeleteFailed

    // File operation errors
    case downloadFailed(String)
    case uploadFailed(String)
    case fileReadFailed
    case fileWriteFailed

    // Terminal errors
    case terminalConnectionFailed(String)
    case terminalConnectionLost
    case terminalPTYFailed

    // Biometric errors
    case biometricNotAvailable
    case biometricAuthFailed(String)

    // Import/export errors
    case importFailed(String)

    // General errors
    case unknown(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .connectionTimeout:
            return "Connection timed out"
        case .connectionLost:
            return "Connection was lost"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .hostUnreachable:
            return "Host is unreachable. Check the hostname and network connection."
        case .hostKeyMismatch(let host, let port):
            return "The host key for \(host):\(port) has changed. This could indicate a security issue or that the server has been reconfigured."

        case .sftpOperationFailed(let message):
            return "SFTP operation failed: \(message)"
        case .permissionDenied:
            return "Permission denied"
        case .fileNotFound:
            return "File or directory not found"
        case .fileAlreadyExists:
            return "A file or directory with this name already exists"
        case .directoryNotEmpty:
            return "Directory is not empty"
        case .invalidPath:
            return "Invalid path"

        case .s3BucketNotFound:
            return "S3 bucket not found"
        case .s3AccessDenied:
            return "Access denied to S3 resource"
        case .s3ObjectNotFound:
            return "S3 object not found"
        case .s3OperationFailed(let message):
            return "S3 operation failed: \(message)"
        case .invalidS3Credentials:
            return "Invalid S3 credentials"

        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .entityNotFound:
            return "Entity not found"

        case .keychainSaveFailed:
            return "Failed to save password to keychain"
        case .keychainReadFailed:
            return "Failed to read password from keychain"
        case .keychainDeleteFailed:
            return "Failed to delete password from keychain"

        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .fileReadFailed:
            return "Failed to read file"
        case .fileWriteFailed:
            return "Failed to write file"

        case .terminalConnectionFailed(let message):
            return "Terminal connection failed: \(message)"
        case .terminalConnectionLost:
            return "Terminal connection was lost"
        case .terminalPTYFailed:
            return "Failed to allocate pseudo-terminal"

        case .biometricNotAvailable:
            return "Touch ID is not available on this Mac"
        case .biometricAuthFailed(let message):
            return "Authentication failed: \(message)"

        case .unknown(let message):
            return message
        case .notConnected:
            return "Not connected to server"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .connectionTimeout, .hostUnreachable:
            return "Please check your network connection and server address."
        case .authenticationFailed:
            return "Please verify your username and password."
        case .permissionDenied, .s3AccessDenied:
            return "You don't have permission to perform this action."
        case .notConnected:
            return "Please connect to a server first."
        case .s3BucketNotFound:
            return "Please check your bucket name and region."
        case .invalidS3Credentials:
            return "Please verify your Access Key ID and Secret Access Key."
        case .terminalConnectionFailed, .terminalConnectionLost:
            return "Please check your network connection and try reconnecting."
        case .terminalPTYFailed:
            return "The server may not support interactive terminals. Please try again."
        case .biometricNotAvailable:
            return "Use a Mac with Touch ID or pair an Apple Watch to enable biometric authentication."
        case .biometricAuthFailed:
            return "Please try again or use your system password."
        case .hostKeyMismatch:
            return "You can replace the stored key and reconnect, or disconnect. Only replace the key if you trust the new server."
        case .sftpOperationFailed:
            return "Check that the file exists, the path is correct, and that you have the required permissions."
        case .fileNotFound:
            return "Confirm the file has not been moved or deleted, then refresh the list."
        case .fileAlreadyExists:
            return "Use a different name, or delete the existing file first."
        case .directoryNotEmpty:
            return "Delete the files inside the directory first, or force-delete the whole directory."
        case .invalidPath:
            return "Check that the path format is correct."
        case .s3ObjectNotFound:
            return "Confirm the object exists, or refresh the list."
        case .s3OperationFailed:
            return "Check the bucket permissions and your network, then try again."
        case .saveFailed, .fetchFailed, .deleteFailed:
            return "Please retry; if the problem persists, restart the app."
        case .downloadFailed, .uploadFailed:
            return "Check your network connection and available disk space, then try again."
        case .fileReadFailed:
            return "Confirm the file is not in use or corrupted."
        case .fileWriteFailed:
            return "Check that the destination has write permission and enough disk space."
        case .unknown:
            return "Please retry; if the problem persists, contact support with the error details."
        case .connectionLost:
            return "Reconnect to the server to resume the operation."
        case .entityNotFound:
            return "The item may have been removed. Refresh and try again."
        case .keychainSaveFailed:
            return "Check the keychain is unlocked and that you have permission to store items."
        case .keychainReadFailed:
            return "Unlock the keychain or re-enter your credentials to continue."
        case .keychainDeleteFailed:
            return "The stored credentials may need to be removed manually from Keychain Access."
        case .importFailed:
            return "Check the file format and ensure it is a valid connection export."
        }
    }
}

// MARK: - Host Key Helpers
extension AppError {
    var isHostKeyMismatch: Bool {
        if case .hostKeyMismatch = self { return true }
        return false
    }
}

// MARK: - Error Conversion
extension AppError {
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let urlError = error as? URLError {
            return fromURLError(urlError)
        }
        if let nsError = error as NSError? {
            if nsError.domain == "com.apple.security" || nsError.domain == "NSOSStatusErrorDomain" {
                return fromKeychainStatus(nsError.code)
            }
            let domain = nsError.domain.lowercased()
            if domain.contains("nio") || domain.contains("ssh") || domain.contains("libssh") {
                return .sftpOperationFailed(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }

    private static func fromURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .connectionLost
        case .timedOut:
            return .connectionTimeout
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .hostUnreachable
        default:
            return .connectionFailed(error.localizedDescription)
        }
    }

    private static func fromKeychainStatus(_ status: Int) -> AppError {
        switch status {
        case -25300: // errSecItemNotFound
            return .entityNotFound
        case -128:   // errSecUserCanceled
            return .unknown("Operation cancelled")
        default:
            return .keychainReadFailed
        }
    }
}
