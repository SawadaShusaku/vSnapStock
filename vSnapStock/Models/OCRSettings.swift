//
//  OCRSettings.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Observation

/// OCR設定を管理するシングルトン
@Observable
@MainActor
final class OCRSettingsManager {

    static let shared = OCRSettingsManager()

    // MARK: - Settings with UserDefaults persistence

    /// 表示するバウンディングボックスの最大数（1-10）
    var maxDisplayCount: Int {
        didSet {
            UserDefaults.standard.set(maxDisplayCount, forKey: Keys.maxDisplayCount)
        }
    }

    /// 最小面積閾値（0.1% - 5%）
    var minAreaThreshold: Double {
        didSet {
            UserDefaults.standard.set(minAreaThreshold, forKey: Keys.minAreaThreshold)
        }
    }

    /// テキストマージの縦方向閾値（0% - 10%）
    var mergeThreshold: Double {
        didSet {
            UserDefaults.standard.set(mergeThreshold, forKey: Keys.mergeThreshold)
        }
    }

    /// スキャン間隔（秒）（0.5 - 3.0）
    var scanInterval: Double {
        didSet {
            UserDefaults.standard.set(scanInterval, forKey: Keys.scanInterval)
        }
    }

    /// 小さなテキストをフィルタリングするかどうか
    var filterSmallText: Bool {
        didSet {
            UserDefaults.standard.set(filterSmallText, forKey: Keys.filterSmallText)
        }
    }

    /// 近接テキストをマージするかどうか（横書き用・縦方向）
    var mergeNearbyText: Bool {
        didSet {
            UserDefaults.standard.set(mergeNearbyText, forKey: Keys.mergeNearbyText)
        }
    }

    /// 縦書きテキストをマージするかどうか（横方向）
    var mergeVerticalText: Bool {
        didSet {
            UserDefaults.standard.set(mergeVerticalText, forKey: Keys.mergeVerticalText)
        }
    }

    /// 縦書きテキストマージの横方向閾値（0% - 10%）
    var verticalTextMergeThreshold: Double {
        didSet {
            UserDefaults.standard.set(verticalTextMergeThreshold, forKey: Keys.verticalTextMergeThreshold)
        }
    }

    // MARK: - Computed Properties (CGFloat for use in services)

    var minAreaThresholdCGFloat: CGFloat {
        CGFloat(minAreaThreshold / 100.0)
    }

    var mergeThresholdCGFloat: CGFloat {
        CGFloat(mergeThreshold / 100.0)
    }

    var verticalTextMergeThresholdCGFloat: CGFloat {
        CGFloat(verticalTextMergeThreshold / 100.0)
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let maxDisplayCount = "ocr_maxDisplayCount"
        static let minAreaThreshold = "ocr_minAreaThreshold"
        static let mergeThreshold = "ocr_mergeThreshold"
        static let scanInterval = "ocr_scanInterval"
        static let filterSmallText = "ocr_filterSmallText"
        static let mergeNearbyText = "ocr_mergeNearbyText"
        static let mergeVerticalText = "ocr_mergeVerticalText"
        static let verticalTextMergeThreshold = "ocr_verticalTextMergeThreshold"
    }

    // MARK: - Default Values

    private enum Defaults {
        static let maxDisplayCount = 5
        static let minAreaThreshold = 0.5  // 0.5%
        static let mergeThreshold = 2.0    // 2%
        static let scanInterval = 1.0      // 1秒
        static let filterSmallText = true
        static let mergeNearbyText = true
        static let mergeVerticalText = true  // デフォルトはON
        static let verticalTextMergeThreshold = 3.0  // 3%
    }

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults or use defaults
        let defaults = UserDefaults.standard

        self.maxDisplayCount = defaults.object(forKey: Keys.maxDisplayCount) as? Int ?? Defaults.maxDisplayCount
        self.minAreaThreshold = defaults.object(forKey: Keys.minAreaThreshold) as? Double ?? Defaults.minAreaThreshold
        self.mergeThreshold = defaults.object(forKey: Keys.mergeThreshold) as? Double ?? Defaults.mergeThreshold
        self.scanInterval = defaults.object(forKey: Keys.scanInterval) as? Double ?? Defaults.scanInterval
        self.filterSmallText = defaults.object(forKey: Keys.filterSmallText) as? Bool ?? Defaults.filterSmallText
        self.mergeNearbyText = defaults.object(forKey: Keys.mergeNearbyText) as? Bool ?? Defaults.mergeNearbyText
        self.mergeVerticalText = defaults.object(forKey: Keys.mergeVerticalText) as? Bool ?? Defaults.mergeVerticalText
        self.verticalTextMergeThreshold = defaults.object(forKey: Keys.verticalTextMergeThreshold) as? Double ?? Defaults.verticalTextMergeThreshold
    }

    // MARK: - Reset to Defaults

    func resetToDefaults() {
        maxDisplayCount = Defaults.maxDisplayCount
        minAreaThreshold = Defaults.minAreaThreshold
        mergeThreshold = Defaults.mergeThreshold
        scanInterval = Defaults.scanInterval
        filterSmallText = Defaults.filterSmallText
        mergeNearbyText = Defaults.mergeNearbyText
        mergeVerticalText = Defaults.mergeVerticalText
        verticalTextMergeThreshold = Defaults.verticalTextMergeThreshold
    }
}
