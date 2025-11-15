//
//  vSnapStockApp.swift
//  vSnapStock
//
//  Created by USER on 2025/11/15.
//

import SwiftUI
import CoreData

@main
struct vSnapStockApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
