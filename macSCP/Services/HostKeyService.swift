//
//  HostKeyService.swift
//  macSCP
//
//  Utility for managing SSH known host keys
//

import Foundation

enum HostKeyService {
    /// Removes the known host key entry for the given host and port.
    /// Uses `ssh-keygen -R [host]:[port]` which handles both the
    /// standard and hashed host key formats in known_hosts.
    static func removeHostKey(host: String, port: Int) throws {
        logInfo("Removing host key for \(host):\(port)", category: .network)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")

        // ssh-keygen -R accepts [host]:port format for non-standard ports
        let hostSpec = port == 22 ? host : "[\(host)]:\(port)"
        process.arguments = ["-R", hostSpec]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logError("Failed to remove host key: \(msg)", category: .network)
            // Don't throw — best effort. The user can still try to reconnect.
        } else {
            logInfo("Host key removed for \(host):\(port)", category: .network)
        }
    }
}
