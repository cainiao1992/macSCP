//
//  AppLogger.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import os

enum AppLogger {
    static let database = Logger(
        subsystem: AppConstants.defaultBundleID,
        category: "database"
    )
    static let network = Logger(
        subsystem: AppConstants.defaultBundleID,
        category: "network"
    )
}
