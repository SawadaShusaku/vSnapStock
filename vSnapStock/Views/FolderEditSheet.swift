//
//  FolderEditSheet.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import SwiftUI
import SwiftData

struct FolderEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allFolders: [Folder]

    let folder: Folder?
    @State private var folderName: String = ""
    @State private var colorManager = ColorSettingsManager.shared

    private var isEditing: Bool {
        folder != nil
    }

    private var title: String {
        isEditing ? String(localized: "folder.edit") : String(localized: "folder.new")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "folder.name"), text: $folderName)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Group {
                    if let gradient = colorManager.backgroundGradient {
                        gradient
                    } else {
                        colorManager.backgroundColor
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        saveFolder()
                    }
                }
            }
        }
        .onAppear {
            if let folder = folder {
                folderName = folder.name
            }
        }
    }

    private func saveFolder() {
        let nameToSave: String
        if folderName.trimmingCharacters(in: .whitespaces).isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            nameToSave = formatter.string(from: Date())
        } else {
            nameToSave = folderName
        }

        if let folder = folder {
            // 編集
            folder.name = nameToSave
            folder.touch()
        } else {
            // 新規作成
            let maxSortOrder = allFolders.map { $0.sortOrder }.max() ?? -1
            let newFolder = Folder(
                name: nameToSave,
                sortOrder: maxSortOrder + 1
            )
            modelContext.insert(newFolder)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    FolderEditSheet(folder: nil)
        .modelContainer(for: Folder.self, inMemory: true)
}
