//
//  OCRModels.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import CoreGraphics

// MARK: - CGRect Extension

extension CGRect {
    /// 矩形の面積
    var area: CGFloat {
        width * height
    }
}

/// テキストの種類
enum TextType: Equatable, Sendable {
    case date(Date)           // 日付テキスト
    case productNameCandidate // 商品名候補
    case general              // その他のテキスト
}

/// 認識されたテキスト項目
@MainActor
struct RecognizedTextItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let boundingBox: CGRect // 正規化座標（0-1、左下原点）
    let textType: TextType

    init(id: UUID = UUID(), text: String, boundingBox: CGRect, textType: TextType) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.textType = textType
    }

    var isDate: Bool {
        if case .date = textType { return true }
        return false
    }

    var isProductNameCandidate: Bool {
        if case .productNameCandidate = textType { return true }
        return false
    }

    var extractedDate: Date? {
        if case .date(let date) = textType { return date }
        return nil
    }

    static func == (lhs: RecognizedTextItem, rhs: RecognizedTextItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.textType == rhs.textType
    }
}

/// 全体のOCR認識結果
@MainActor
struct OCRResult: Sendable {
    let items: [RecognizedTextItem]

    var dateItem: RecognizedTextItem? {
        items.first { $0.isDate }
    }

    var productNameCandidates: [RecognizedTextItem] {
        items.filter { !$0.isDate }
    }

    var extractedDate: Date? {
        dateItem?.extractedDate
    }

    static let empty = OCRResult(items: [])
}
