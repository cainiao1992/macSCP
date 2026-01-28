//
//  ContentView.swift
//  macSCP
//
//  Created by Nevil Macwan on 09/10/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        ConnectionListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [SSHConnection.self, ConnectionFolder.self],
            inMemory: true
        )
}
