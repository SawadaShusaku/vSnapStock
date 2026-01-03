//
//  TextRecognitionService.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import Vision
import UIKit
import CoreMedia
import CoreVideo

/// Vision APIによるOCR処理を担当するActor
actor TextRecognitionService {

    // MARK: - Public Methods

    /// CVPixelBufferからテキストを認識（リアルタイム用）
    @MainActor
    func recognize(from pixelBuffer: CVPixelBuffer) async -> OCRResult {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [
            Locale.Language(identifier: "ja-JP"),
            Locale.Language(identifier: "en-US")
        ]
        request.automaticallyDetectsLanguage = true
        request.recognitionLevel = .accurate

        do {
            let observations = try await request.perform(on: pixelBuffer, orientation: .right)
            return processObservations(observations)
        } catch {
            print("Text recognition failed: \(error)")
            return .empty
        }
    }

    /// UIImageからテキストを認識（静止画用）
    @MainActor
    func recognize(from image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else { return .empty }

        var request = RecognizeTextRequest()
        request.recognitionLanguages = [
            Locale.Language(identifier: "ja-JP"),
            Locale.Language(identifier: "en-US")
        ]
        request.automaticallyDetectsLanguage = true
        request.recognitionLevel = .accurate

        do {
            let orientation = cgImageOrientation(from: image.imageOrientation)
            let observations = try await request.perform(on: cgImage, orientation: orientation)
            return processObservations(observations)
        } catch {
            print("Text recognition failed: \(error)")
            return .empty
        }
    }

    /// CMSampleBufferからテキストを認識（リアルタイム用）
    @MainActor
    func recognize(from sampleBuffer: CMSampleBuffer) async -> OCRResult {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .empty
        }
        return await recognize(from: pixelBuffer)
    }

    // MARK: - Private Methods

    /// 認識結果を処理してOCRResultに変換
    @MainActor
    private func processObservations(_ observations: [RecognizedTextObservation]) -> OCRResult {
        var items: [RecognizedTextItem] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string
            let boundingBox = observation.boundingBox.cgRect

            if let date = extractDateFromText(text) {
                items.append(RecognizedTextItem(
                    text: text,
                    boundingBox: boundingBox,
                    textType: .date(date)
                ))
            } else if isProductNameCandidate(text) {
                items.append(RecognizedTextItem(
                    text: text,
                    boundingBox: boundingBox,
                    textType: .productNameCandidate
                ))
            } else {
                items.append(RecognizedTextItem(
                    text: text,
                    boundingBox: boundingBox,
                    textType: .general
                ))
            }
        }

        // 設定を取得
        let settings = OCRSettingsManager.shared

        // 小さすぎるテキストをフィルタリング（設定に基づく）
        var filteredItems = items
        if settings.filterSmallText {
            let minAreaThreshold = settings.minAreaThresholdCGFloat
            filteredItems = items.filter { $0.boundingBox.area >= minAreaThreshold }
        }

        // 横書きテキストをマージ（縦方向の近接、設定に基づく）
        var processedItems: [RecognizedTextItem]
        if settings.mergeNearbyText {
            processedItems = mergeHorizontalTextItems(filteredItems, threshold: settings.mergeThresholdCGFloat)
        } else {
            processedItems = filteredItems
        }

        // 縦書きテキストをマージ（横方向の近接、設定に基づく）
        if settings.mergeVerticalText {
            processedItems = mergeVerticalTextItems(processedItems, threshold: settings.verticalTextMergeThresholdCGFloat)
        }

        // 面積が大きい順にソート
        let sortedItems = processedItems.sorted { $0.boundingBox.area > $1.boundingBox.area }

        return OCRResult(items: sortedItems)
    }

    /// 横書きテキストを縦方向にマージ（Y軸近接）
    @MainActor
    private func mergeHorizontalTextItems(_ items: [RecognizedTextItem], threshold: CGFloat) -> [RecognizedTextItem] {
        guard !items.isEmpty else { return [] }

        // 日付は別扱い（マージしない）
        let dateItems = items.filter { $0.isDate }
        var nonDateItems = items.filter { !$0.isDate }

        // Y座標でソート（Vision座標は左下原点なので、maxYが大きい=画面上部）
        nonDateItems.sort { $0.boundingBox.maxY > $1.boundingBox.maxY }

        var mergedItems: [RecognizedTextItem] = []
        var currentGroup: [RecognizedTextItem] = []

        // 縦方向の近接閾値（設定から取得）
        let verticalThreshold = threshold

        for item in nonDateItems {
            if currentGroup.isEmpty {
                currentGroup.append(item)
            } else {
                // 現在のグループの最後のアイテムとの距離をチェック
                let lastItem = currentGroup.last!
                let verticalDistance = abs(lastItem.boundingBox.minY - item.boundingBox.maxY)

                if verticalDistance < verticalThreshold {
                    // 近接している場合はグループに追加
                    currentGroup.append(item)
                } else {
                    // 離れている場合は現在のグループをマージして新しいグループを開始
                    if let merged = mergeGroup(currentGroup) {
                        mergedItems.append(merged)
                    }
                    currentGroup = [item]
                }
            }
        }

        // 最後のグループを処理
        if let merged = mergeGroup(currentGroup) {
            mergedItems.append(merged)
        }

        return dateItems + mergedItems
    }

    /// グループ内のアイテムを1つにマージ
    @MainActor
    private func mergeGroup(_ group: [RecognizedTextItem]) -> RecognizedTextItem? {
        guard !group.isEmpty else { return nil }
        guard group.count > 1 else { return group.first }

        // テキストを結合
        let combinedText = group.map { $0.text }.joined(separator: " ")

        // バウンディングボックスを結合（全体を囲む矩形）
        let minX = group.map { $0.boundingBox.minX }.min() ?? 0
        let minY = group.map { $0.boundingBox.minY }.min() ?? 0
        let maxX = group.map { $0.boundingBox.maxX }.max() ?? 0
        let maxY = group.map { $0.boundingBox.maxY }.max() ?? 0

        let combinedBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // 結合テキストで日付を再チェック
        if let date = extractDateFromText(combinedText) {
            return RecognizedTextItem(
                text: combinedText,
                boundingBox: combinedBox,
                textType: .date(date)
            )
        }

        return RecognizedTextItem(
            text: combinedText,
            boundingBox: combinedBox,
            textType: .productNameCandidate
        )
    }

    /// 縦書きテキストを横方向にマージ（X軸近接）
    @MainActor
    private func mergeVerticalTextItems(_ items: [RecognizedTextItem], threshold: CGFloat) -> [RecognizedTextItem] {
        guard !items.isEmpty else { return [] }

        // 日付は別扱い（マージしない）
        let dateItems = items.filter { $0.isDate }
        var nonDateItems = items.filter { !$0.isDate }

        // X座標でソート（右から左へ、縦書きの読み順）
        nonDateItems.sort { $0.boundingBox.maxX > $1.boundingBox.maxX }

        var mergedItems: [RecognizedTextItem] = []
        var currentGroup: [RecognizedTextItem] = []

        // 横方向の近接閾値
        let horizontalThreshold = threshold

        for item in nonDateItems {
            if currentGroup.isEmpty {
                currentGroup.append(item)
            } else {
                // 現在のグループの最後のアイテムとの横方向距離をチェック
                let lastItem = currentGroup.last!
                let horizontalDistance = abs(lastItem.boundingBox.minX - item.boundingBox.maxX)

                // 縦方向の重なりもチェック（同じ行にあるか）
                let verticalOverlap = hasVerticalOverlap(lastItem.boundingBox, item.boundingBox)

                if horizontalDistance < horizontalThreshold && verticalOverlap {
                    // 横方向に近接し、縦方向に重なりがある場合はグループに追加
                    currentGroup.append(item)
                } else {
                    // 離れている場合は現在のグループをマージして新しいグループを開始
                    if let merged = mergeVerticalGroup(currentGroup) {
                        mergedItems.append(merged)
                    }
                    currentGroup = [item]
                }
            }
        }

        // 最後のグループを処理
        if let merged = mergeVerticalGroup(currentGroup) {
            mergedItems.append(merged)
        }

        return dateItems + mergedItems
    }

    /// 2つのバウンディングボックスが縦方向に重なりを持つかチェック
    @MainActor
    private func hasVerticalOverlap(_ box1: CGRect, _ box2: CGRect) -> Bool {
        // Y座標の範囲が重なっているかチェック
        let overlap = min(box1.maxY, box2.maxY) - max(box1.minY, box2.minY)
        let minHeight = min(box1.height, box2.height)
        // 最小高さの30%以上重なっていれば同じ行とみなす
        return overlap > minHeight * 0.3
    }

    /// 縦書きグループ内のアイテムを1つにマージ
    @MainActor
    private func mergeVerticalGroup(_ group: [RecognizedTextItem]) -> RecognizedTextItem? {
        guard !group.isEmpty else { return nil }
        guard group.count > 1 else { return group.first }

        // テキストを結合（縦書きなので改行なしで結合）
        let combinedText = group.map { $0.text }.joined()

        // バウンディングボックスを結合（全体を囲む矩形）
        let minX = group.map { $0.boundingBox.minX }.min() ?? 0
        let minY = group.map { $0.boundingBox.minY }.min() ?? 0
        let maxX = group.map { $0.boundingBox.maxX }.max() ?? 0
        let maxY = group.map { $0.boundingBox.maxY }.max() ?? 0

        let combinedBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // 結合テキストで日付を再チェック
        if let date = extractDateFromText(combinedText) {
            return RecognizedTextItem(
                text: combinedText,
                boundingBox: combinedBox,
                textType: .date(date)
            )
        }

        return RecognizedTextItem(
            text: combinedText,
            boundingBox: combinedBox,
            textType: .productNameCandidate
        )
    }

    /// UIImage.Orientation を CGImagePropertyOrientation に変換
    private nonisolated func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// 商品名候補かどうかを判定
    private nonisolated func isProductNameCandidate(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }

        // 数字のみの場合は除外
        let digitsOnly = text.allSatisfy { $0.isNumber || $0.isWhitespace }
        if digitsOnly { return false }

        // 日本語を含むか、3文字以上であれば商品名候補
        let containsJapanese = text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0x3040...0x309F).contains(value) ||  // ひらがな
                   (0x30A0...0x30FF).contains(value) ||  // カタカナ
                   (0x4E00...0x9FFF).contains(value)     // 漢字
        }

        return containsJapanese || text.count >= 3
    }

    /// 単一テキストから日付を抽出
    private nonisolated func extractDateFromText(_ text: String) -> Date? {
        // 年月日のパターン（日付あり）
        let fullDatePatterns: [String] = [
            #"(\d{2,4})[\.．]\s*(\d{1,2})[\.．]\s*(\d{1,2})"#,
            #"(\d{2,4})[/／]\s*(\d{1,2})[/／]\s*(\d{1,2})"#,
            #"(\d{2,4})[-ー]\s*(\d{1,2})[-ー]\s*(\d{1,2})"#,
            #"(\d{2,4})年\s*(\d{1,2})月\s*(\d{1,2})日"#,
        ]

        for pattern in fullDatePatterns {
            if let date = extractFullDate(from: text, pattern: pattern) {
                return date
            }
        }

        // 年月のみのパターン（日付省略、月末を使用）
        let yearMonthPatterns: [String] = [
            #"(\d{2,4})[\.．]\s*(\d{1,2})(?![\.．/／\-ー\d])"#,  // 2026. 7 または 2026.7
            #"(\d{2,4})[/／]\s*(\d{1,2})(?![/／\-ー\d])"#,       // 2026/ 7 または 2026/7
            #"(\d{2,4})[-ー]\s*(\d{1,2})(?![-ー\d])"#,           // 2026- 7 または 2026-7
            #"(\d{2,4})年\s*(\d{1,2})月(?!\d)"#,                 // 2026年7月
        ]

        for pattern in yearMonthPatterns {
            if let date = extractYearMonthDate(from: text, pattern: pattern) {
                return date
            }
        }

        return nil
    }

    /// 正規表現で年月日を抽出
    private nonisolated func extractFullDate(from text: String, pattern: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        guard match.numberOfRanges >= 4,
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let dayRange = Range(match.range(at: 3), in: text) else {
            return nil
        }

        var year = Int(text[yearRange]) ?? 0
        let month = Int(text[monthRange]) ?? 0
        let day = Int(text[dayRange]) ?? 0

        // 2桁年を4桁に変換
        if year < 100 {
            year += 2000
        }

        // 妥当性チェック
        guard year >= 2000 && year <= 2100,
              month >= 1 && month <= 12,
              day >= 1 && day <= 31 else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return Calendar.current.date(from: components)
    }

    /// 正規表現で年月を抽出（日は月末を使用）
    private nonisolated func extractYearMonthDate(from text: String, pattern: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        guard match.numberOfRanges >= 3,
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text) else {
            return nil
        }

        var year = Int(text[yearRange]) ?? 0
        let month = Int(text[monthRange]) ?? 0

        // 2桁年を4桁に変換
        if year < 100 {
            year += 2000
        }

        // 妥当性チェック
        guard year >= 2000 && year <= 2100,
              month >= 1 && month <= 12 else {
            return nil
        }

        // 月末日を計算
        var components = DateComponents()
        components.year = year
        components.month = month + 1  // 翌月
        components.day = 0            // 翌月の0日 = 今月の最終日

        return Calendar.current.date(from: components)
    }
}
