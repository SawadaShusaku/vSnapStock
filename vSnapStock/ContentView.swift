//
//  ContentView.swift
//  vSnapStock
//
//  Created by USER on 2025/11/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Card.self, inMemory: true)
}
