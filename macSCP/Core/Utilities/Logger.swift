//
//  Logger.swift
//  macSCP
//
//  Centralized logging using OSLog
//

import Foundation
import os.log

enum LogCategory: String, Sendable {
    case app = "App"
    case sftp = "SFTP"
    case s3 = "S3"
    case keychain = "Keychain"
    case database = "Database"
    case ui = "UI"
    case network = "Network"
    case auth = "Auth"
}

enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error

    nonisolated var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    nonisolated var prefix: String {
        switch self {
        case .debug: return "[DEBUG]"
        case .info: return "[INFO]"
        case .warning: return "[WARNING]"
        case .error: return "[ERROR]"
        }
    }
}

final class Logger: Sendable {
    private let subsystem: String
    private let loggers: [LogCategory: os.Logger]

    init(subsystem: String? = nil) {
        let bundleId = subsystem ?? Bundle.main.bundleIdentifier ?? "com.macSCP"
        self.subsystem = bundleId
        var builtLoggers: [LogCategory: os.Logger] = [:]
        for category in [LogCategory.app, .sftp, .s3, .keychain, .database, .ui, .network, .auth] {
            builtLoggers[category] = os.Logger(subsystem: bundleId, category: category.rawValue)
        }
        loggers = builtLoggers
    }

    nonisolated func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let logger = loggers[category] ?? os.Logger(subsystem: subsystem, category: category.rawValue)
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.prefix) [\(fileName):\(line)] \(function) - \(message)"

        logger.log(level: level.osLogType, "\(logMessage)")

        #if DEBUG
        print(logMessage)
        #endif
    }

    nonisolated func debug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    nonisolated func info(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    nonisolated func warning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    nonisolated func error(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Singleton Access

extension Logger {
    nonisolated static let shared = Logger()
}

// MARK: - Convenience Functions

nonisolated func logDebug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

nonisolated func logInfo(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

nonisolated func logWarning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

nonisolated func logError(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}
