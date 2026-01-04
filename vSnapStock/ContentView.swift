//
//  ContentView.swift
//  vSnapStock
//
//  Created by USER on 2025/11/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FolderListView(navigationPath: $navigationPath)
                .navigationDestination(for: AppNavigationPath.self) { path in
                    switch path {
                    case .folderDetail(let folder):
                        FolderCardsView(folder: folder)
                    }
                }
        }
        .onAppear {
            FolderMigrationService.migrateExistingCards(modelContext: modelContext)

            // 前回開いていたフォルダを復元
            if let lastFolderIdString = UserDefaults.standard.string(forKey: "LastOpenedFolderId"),
               let lastFolderId = UUID(uuidString: lastFolderIdString) {
                let descriptor = FetchDescriptor<Folder>(
                    predicate: #Predicate { $0.id == lastFolderId }
                )
                if let folder = try? modelContext.fetch(descriptor).first {
                    navigationPath.append(AppNavigationPath.folderDetail(folder))
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Card.self, inMemory: true)
}
