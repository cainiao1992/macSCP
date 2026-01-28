//
//  String+Extensions.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmptyOrWhitespace: Bool {
        trimmed.isEmpty
    }
}
