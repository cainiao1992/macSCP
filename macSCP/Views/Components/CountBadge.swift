//
//  CountBadge.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import SwiftUI

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
