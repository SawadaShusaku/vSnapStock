//
//  FolderMigrationService.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import SwiftData
import Foundation

class FolderMigrationService {
    /// 既存のカード（folder == nil）をデフォルトフォルダに移行する
    static func migrateExistingCards(modelContext: ModelContext) {
        // folder == nil のカードを検索
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.folder == nil }
        )

        guard let cardsWithoutFolder = try? modelContext.fetch(descriptor),
              !cardsWithoutFolder.isEmpty else {
            return
        }

        // デフォルトフォルダ（2025-12-28）を取得または作成
        let defaultFolderName = "2025-12-28"
        let defaultFolder = getOrCreateDefaultFolder(
            modelContext: modelContext,
            name: defaultFolderName
        )

        // すべてのカードをデフォルトフォルダに割り当て
        for card in cardsWithoutFolder {
            card.folder = defaultFolder
        }

        try? modelContext.save()
    }

    /// 指定された名前のフォルダを取得、存在しない場合は作成
    static func getOrCreateDefaultFolder(
        modelContext: ModelContext,
        name: String
    ) -> Folder {
        // 既存のフォルダを検索
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate { $0.name == name }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // 新しいフォルダを作成
        let folder = Folder(name: name, sortOrder: 0)
        modelContext.insert(folder)
        return folder
    }

    /// 日付をもとにフォルダを取得または作成
    static func ensureDefaultFolderForDate(_ date: Date, modelContext: ModelContext) -> Folder {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let folderName = formatter.string(from: date)

        return getOrCreateDefaultFolder(modelContext: modelContext, name: folderName)
    }
}
