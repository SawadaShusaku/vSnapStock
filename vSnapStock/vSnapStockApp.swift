//
//  vSnapStockApp.swift
//  vSnapStock
//
//  Created by USER on 2025/11/15.
//

import SwiftUI
import SwiftData

@main
struct vSnapStockApp: App {
    @State private var colorManager = ColorSettingsManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Card.self, Folder.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorManager.appearanceMode.colorScheme)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
