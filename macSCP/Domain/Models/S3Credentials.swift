//
//  S3Credentials.swift
//  macSCP
//
//  Model for S3 credentials stored in Keychain
//

import Foundation

struct S3Credentials: Codable, Sendable {
    let accessKeyId: String
    let secretAccessKey: String

    init(accessKeyId: String, secretAccessKey: String) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}
