//
//  SSHConfigParser.swift
//  macSCP
//
//  Stateless SSH config file parser that produces structured entries
//

import Foundation

/// Parses OpenSSH configuration files into structured entries for import.
///
/// The parser is stateless and pure — it takes text or a file URL and returns
/// a `ParseResult` containing parsed entries, wildcard skip counts, and any
/// include warnings. It handles:
/// - Host blocks with HostName, Port, User, IdentityFile directives
/// - Recursive Include directives with glob pattern expansion
/// - Wildcard Host patterns (containing `*` or `?`) are skipped and counted
/// - Circular include protection via a visited-path set
struct SSHConfigParser: Sendable {

    // MARK: - Parse Result

    /// Aggregated result from parsing an SSH config file.
    struct ParseResult: Sendable {
        let entries: [SSHConfigEntry]
        let wildcardCount: Int
        let includeWarnings: [String]
        let updatedVisitedPaths: Set<String>
    }

    // MARK: - Public API

    /// Parses an SSH config file at the given URL.
    ///
    /// - Parameter fileURL: Absolute file URL to the SSH config file.
    /// - Returns: A `ParseResult` with all parsed entries and metadata.
    /// - Throws: `AppError.importFailed` if the file cannot be read.
    func parse(fileURL: URL) throws -> ParseResult {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let baseURL = fileURL.deletingLastPathComponent()
            return parse(content: content, baseURL: baseURL, visitedPaths: [fileURL.path])
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.importFailed("Cannot read file: \(error.localizedDescription)")
        }
    }

    /// Parses SSH config text content directly (pure function, no I/O).
    ///
    /// - Parameters:
    ///   - content: Raw SSH config text.
    ///   - baseURL: Base directory for resolving relative Include paths.
    /// - Returns: A `ParseResult` with all parsed entries and metadata.
    func parse(content: String, baseURL: URL? = nil) -> ParseResult {
        parse(content: content, baseURL: baseURL, visitedPaths: [])
    }

    // MARK: - Internal Parser

    private func parse(
        content: String,
        baseURL: URL?,
        visitedPaths: Set<String>
    ) -> ParseResult {
        var entries: [SSHConfigEntry] = []
        var wildcardCount = 0
        var includeWarnings: [String] = []
        var visited = visitedPaths

        let blocks = splitIntoBlocks(content)

        for block in blocks {
            if block.directive.lowercased() == "include" {
                let includeResult = resolveInclude(
                    path: block.value,
                    baseURL: baseURL,
                    visitedPaths: visited
                )
                entries.append(contentsOf: includeResult.entries)
                wildcardCount += includeResult.wildcardCount
                includeWarnings.append(contentsOf: includeResult.includeWarnings)
                visited = includeResult.updatedVisitedPaths
                continue
            }

            // Only "Host" directive starts a connection entry block
            guard block.directive.lowercased() == "host" else { continue }

            let tokens = block.value.split(whereSeparator: { $0.isWhitespace }).map(String.init)

            var nonWildcardTokens: [String] = []
            for token in tokens {
                if token.contains("*") || token.contains("?") {
                    wildcardCount += 1
                } else {
                    nonWildcardTokens.append(token)
                }
            }

            // Parse block properties
            let properties = parseProperties(block.properties)
            let hostName = properties["hostname"]
            let port = parsePort(properties["port"])
            let user = properties["user"]
            let identityFile = properties["identityfile"].map { expandPath($0) }

            for token in nonWildcardTokens {
                let entry = SSHConfigEntry(
                    host: token,
                    hostName: hostName,
                    port: port,
                    user: user,
                    identityFile: identityFile
                )
                entries.append(entry)
            }
        }

        return ParseResult(
            entries: entries,
            wildcardCount: wildcardCount,
            includeWarnings: includeWarnings,
            updatedVisitedPaths: visited
        )
    }

    // MARK: - Block Splitting

    /// A parsed block from the SSH config file.
    private struct ConfigBlock {
        let directive: String
        let value: String
        let properties: [String]
    }

    /// Splits config content into Host/Include blocks.
    ///
    /// Each `Host` or `Include` directive starts a new block. Subsequent
    /// key-value lines belong to the current block until the next Host/Include.
    private func splitIntoBlocks(_ content: String) -> [ConfigBlock] {
        var blocks: [ConfigBlock] = []
        var currentDirective: String?
        var currentValue: String = ""
        var currentProperties: [String] = []

        let lines = content.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let (key, value) = parseLine(line) {
                let lowerKey = key.lowercased()
                if lowerKey == "host" || lowerKey == "include" {
                    // Flush previous block
                    if let directive = currentDirective {
                        blocks.append(ConfigBlock(
                            directive: directive,
                            value: currentValue,
                            properties: currentProperties
                        ))
                    }
                    currentDirective = lowerKey
                    currentValue = value
                    currentProperties = []
                } else {
                    currentProperties.append(line)
                }
            }
        }

        // Flush final block
        if let directive = currentDirective {
            blocks.append(ConfigBlock(
                directive: directive,
                value: currentValue,
                properties: currentProperties
            ))
        }

        return blocks
    }

    // MARK: - Line Parsing

    /// Strips inline comments from a line.
    private func stripComment(_ line: String) -> String {
        // SSH config: # at start of line is a comment
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return ""
        }
        return line
    }

    /// Parses a key-value line in either `Key Value` or `Key=Value` format.
    private func parseLine(_ line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try Key=Value first
        if let eqIndex = trimmed.firstIndex(of: "=") {
            let key = trimmed[trimmed.startIndex..<eqIndex].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty && !value.isEmpty {
                return (key, value)
            }
        }

        // Key Value format: split on first whitespace
        let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2 else { return nil }
        let key = String(parts[0])
        let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return (key, value)
    }

    /// Parses block property lines into a case-insensitive dictionary.
    /// Duplicate keys: last value wins (standard SSH config behavior).
    private func parseProperties(_ lines: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for line in lines {
            if let (key, value) = parseLine(line) {
                result[key.lowercased()] = value
            }
        }
        return result
    }

    // MARK: - Port Parsing

    /// Parses a port string, clamping to 1...65535, defaulting to 22.
    private func parsePort(_ value: String?) -> Int {
        guard let value, let port = Int(value) else { return 22 }
        guard (1...65535).contains(port) else { return 22 }
        return port
    }

    // MARK: - Path Expansion

    /// Expands `~` in a path to the user's home directory.
    private func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    // MARK: - Include Resolution

    /// Result from resolving an Include directive.
    private struct IncludeResult {
        let entries: [SSHConfigEntry]
        let wildcardCount: Int
        let includeWarnings: [String]
        let updatedVisitedPaths: Set<String>
    }

    /// Resolves an Include directive, handling glob patterns and recursion.
    private func resolveInclude(
        path: String,
        baseURL: URL?,
        visitedPaths: Set<String>
    ) -> IncludeResult {
        var visited = visitedPaths
        var allEntries: [SSHConfigEntry] = []
        var totalWildcards = 0
        var warnings: [String] = []

        let expandedPath = expandPath(path)

        // Resolve relative paths against baseURL
        let resolvedPaths = resolveGlobPattern(expandedPath, baseURL: baseURL)

        for filePath in resolvedPaths {
            let absolutePath = (filePath as NSString).standardizingPath

            // Circular include protection
            if visited.contains(absolutePath) {
                continue
            }
            visited.insert(absolutePath)

            let fileURL = URL(fileURLWithPath: absolutePath)
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let newBaseURL = fileURL.deletingLastPathComponent()
                let subResult = parse(content: content, baseURL: newBaseURL, visitedPaths: visited)
                allEntries.append(contentsOf: subResult.entries)
                totalWildcards += subResult.wildcardCount
                warnings.append(contentsOf: subResult.includeWarnings)
                visited = subResult.updatedVisitedPaths
            } catch {
                let displayName = (filePath as NSString).lastPathComponent
                warnings.append("Failed to include \(displayName): \(error.localizedDescription)")
            }
        }

        if resolvedPaths.isEmpty {
            warnings.append("Include path not found: \(path)")
        }

        return IncludeResult(
            entries: allEntries,
            wildcardCount: totalWildcards,
            includeWarnings: warnings,
            updatedVisitedPaths: visited
        )
    }

    /// Expands glob patterns in include paths, returning matching file paths.
    private func resolveGlobPattern(_ pattern: String, baseURL: URL?) -> [String] {
        let expandedPattern: String
        if !pattern.hasPrefix("/") && !pattern.hasPrefix("~"), let baseURL = baseURL {
            // Relative path — resolve against baseURL
            expandedPattern = baseURL.appendingPathComponent(pattern).path
        } else {
            expandedPattern = pattern
        }

        // Check if pattern contains glob characters
        if expandedPattern.contains("*") || expandedPattern.contains("?") {
            // Use FileManager glob matching
            return expandGlob(expandedPattern)
        }

        // Single file path
        let standardizedPath = (expandedPattern as NSString).standardizingPath
        if FileManager.default.fileExists(atPath: standardizedPath) {
            return [standardizedPath]
        }
        return []
    }

    /// Expands a glob pattern to matching file paths.
    private func expandGlob(_ pattern: String) -> [String] {
        let dirPath = (pattern as NSString).deletingLastPathComponent
        let filePattern = (pattern as NSString).lastPathComponent

        guard FileManager.default.fileExists(atPath: dirPath) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            let predicate = NSPredicate(format: "SELF LIKE %@", filePattern)
            let matching = contents.filter { predicate.evaluate(with: $0) }
            return matching.map { (dirPath as NSString).appendingPathComponent($0) }
        } catch {
            return []
        }
    }
}
