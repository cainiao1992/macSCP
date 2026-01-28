//
//  AllConnectionsRow.swift
//  macSCP
//
//  Created by Nevil Macwan on 28/01/26.
//

import SwiftUI

struct AllConnectionsRow: View {
    let count: Int
    
    var body: some View {
        NavigationLink(value: SidebarSelection.all) {
            HStack {
                Label("All", systemImage: "tray.full.fill")
                Spacer()
                CountBadge(count: count)
            }
        }
    }
}
