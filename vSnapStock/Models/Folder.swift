//
//  Folder.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \Card.folder)
    var cards: [Card]?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }

    func touch() {
        self.updatedAt = Date()
    }
}
