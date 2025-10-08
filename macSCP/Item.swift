//
//  Item.swift
//  macSCP
//
//  Created by Nevil Macwan on 09/10/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
