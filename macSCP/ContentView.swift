//
//  ContentView.swift
//  macSCP
//
//  Created by Nevil Macwan on 09/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ConnectionListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ConnectionFolder.self, SSHConnection.self], inMemory: true)
}
