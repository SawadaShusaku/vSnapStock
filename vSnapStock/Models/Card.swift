//
//  Card.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import SwiftData

@Model
final class Card {
    var id: UUID
    var title: String
    var cardDescription: String
    @Attribute(.externalStorage) var photos: [Data]
    var expirationDate: Date?
    var useByDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var sortOrder: Int
    var folder: Folder?

    init(
        id: UUID = UUID(),
        title: String = "",
        cardDescription: String = "",
        photos: [Data] = [],
        expirationDate: Date? = nil,
        useByDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        sortOrder: Int = 0,
        folder: Folder? = nil
    ) {
        self.id = id
        self.title = title
        self.cardDescription = cardDescription
        self.photos = photos
        self.expirationDate = expirationDate
        self.useByDate = useByDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.sortOrder = sortOrder
        self.folder = folder
    }

    /// 更新日時を自動更新
    func touch() {
        self.updatedAt = Date()
    }

    /// ゴミ箱に移動
    func moveToTrash() {
        self.isDeleted = true
        self.deletedAt = Date()
        touch()
    }

    /// ゴミ箱から復元
    func restore() {
        self.isDeleted = false
        self.deletedAt = nil
        touch()
    }

    /// アーカイブ
    func archive() {
        self.isArchived = true
        touch()
    }

    /// アーカイブ解除
    func unarchive() {
        self.isArchived = false
        touch()
    }

    /// 削除から7日経過したかどうか
    var shouldBeDeleted: Bool {
        guard let deletedAt = deletedAt else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return deletedAt < sevenDaysAgo
    }
}
