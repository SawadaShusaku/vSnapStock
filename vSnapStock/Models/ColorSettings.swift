//
//  ColorSettings.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

// MARK: - Gradient Settings
struct GradientSettings: Codable, Equatable {
    var isEnabled: Bool
    var startColor: RGBAColor
    var endColor: RGBAColor
    var angle: Double // 0-360度

    init(isEnabled: Bool = false, startColor: RGBAColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1), endColor: RGBAColor = RGBAColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), angle: Double = 180) {
        self.isEnabled = isEnabled
        self.startColor = startColor
        self.endColor = endColor
        self.angle = angle
    }

    var gradient: LinearGradient {
        let radians = angle * .pi / 180
        let startPoint = UnitPoint(x: 0.5 - cos(radians) * 0.5, y: 0.5 - sin(radians) * 0.5)
        let endPoint = UnitPoint(x: 0.5 + cos(radians) * 0.5, y: 0.5 + sin(radians) * 0.5)
        return LinearGradient(
            colors: [startColor.color, endColor.color],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// MARK: - Color Preset
struct ColorPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var cardColor: RGBAColor
    var backgroundColor: RGBAColor
    var backgroundGradient: GradientSettings?
    var cardGradient: GradientSettings?

    init(id: UUID = UUID(), name: String, cardColor: RGBAColor, backgroundColor: RGBAColor, backgroundGradient: GradientSettings? = nil, cardGradient: GradientSettings? = nil) {
        self.id = id
        self.name = name
        self.cardColor = cardColor
        self.backgroundColor = backgroundColor
        self.backgroundGradient = backgroundGradient
        self.cardGradient = cardGradient
    }

    var hasGradient: Bool {
        (backgroundGradient?.isEnabled ?? false) || (cardGradient?.isEnabled ?? false)
    }

    // デフォルトプリセット
    static let defaultPresets: [ColorPreset] = [
        ColorPreset(
            name: "ライト",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        ),
        ColorPreset(
            name: "ダーク",
            cardColor: RGBAColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ),
        ColorPreset(
            name: "クリーム",
            cardColor: RGBAColor(red: 1.0, green: 0.99, blue: 0.94, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1.0)
        ),
        ColorPreset(
            name: "ミント",
            cardColor: RGBAColor(red: 0.9, green: 1.0, blue: 0.95, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.82, green: 0.94, blue: 0.88, alpha: 1.0)
        ),
        ColorPreset(
            name: "スカイ",
            cardColor: RGBAColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.82, green: 0.88, blue: 0.94, alpha: 1.0)
        ),
        ColorPreset(
            name: "ピーチ",
            cardColor: RGBAColor(red: 1.0, green: 0.95, blue: 0.92, alpha: 1.0),
            backgroundColor: RGBAColor(red: 0.98, green: 0.88, blue: 0.82, alpha: 1.0)
        )
    ]

    // グラデーションプリセット
    static let gradientPresets: [ColorPreset] = [
        ColorPreset(
            name: "サンセット",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
            backgroundColor: RGBAColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),
                endColor: RGBAColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0),
                angle: 135
            )
        ),
        ColorPreset(
            name: "オーシャン",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
            backgroundColor: RGBAColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0),
                endColor: RGBAColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1.0),
                angle: 180
            )
        ),
        ColorPreset(
            name: "オーロラ",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85),
            backgroundColor: RGBAColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0),
                endColor: RGBAColor(red: 0.2, green: 0.8, blue: 0.6, alpha: 1.0),
                angle: 135
            )
        ),
        ColorPreset(
            name: "フレイム",
            cardColor: RGBAColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.9),
            backgroundColor: RGBAColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1.0),
                endColor: RGBAColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0),
                angle: 180
            )
        ),
        ColorPreset(
            name: "ギャラクシー",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
            backgroundColor: RGBAColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 0.1, green: 0.0, blue: 0.3, alpha: 1.0),
                endColor: RGBAColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1.0),
                angle: 135
            )
        ),
        ColorPreset(
            name: "フォレスト",
            cardColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9),
            backgroundColor: RGBAColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1.0),
            backgroundGradient: GradientSettings(
                isEnabled: true,
                startColor: RGBAColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 1.0),
                endColor: RGBAColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1.0),
                angle: 180
            )
        )
    ]
}

// MARK: - RGBA Color (Codable)
struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
}

// MARK: - App Appearance Mode
enum AppAppearanceMode: Int, Codable, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Color Settings Manager
@Observable
class ColorSettingsManager {
    static let shared = ColorSettingsManager()

    var currentPreset: ColorPreset {
        didSet {
            saveSettings()
        }
    }

    var customPresets: [ColorPreset] {
        didSet {
            saveSettings()
        }
    }

    var appearanceMode: AppAppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: appearanceModeKey)
        }
    }

    var cardColor: Color {
        currentPreset.cardColor.color
    }

    var backgroundColor: Color {
        currentPreset.backgroundColor.color
    }

    var hasBackgroundGradient: Bool {
        currentPreset.backgroundGradient?.isEnabled ?? false
    }

    var backgroundGradient: LinearGradient? {
        guard let gradient = currentPreset.backgroundGradient, gradient.isEnabled else {
            return nil
        }
        return gradient.gradient
    }

    var hasCardGradient: Bool {
        currentPreset.cardGradient?.isEnabled ?? false
    }

    var cardGradient: LinearGradient? {
        guard let gradient = currentPreset.cardGradient, gradient.isEnabled else {
            return nil
        }
        return gradient.gradient
    }

    private let userDefaultsKey = "colorSettings"
    private let customPresetsKey = "customColorPresets"
    private let appearanceModeKey = "appAppearanceMode"

    private init() {
        // 保存された設定を読み込む
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let preset = try? JSONDecoder().decode(ColorPreset.self, from: data) {
            self.currentPreset = preset
        } else {
            self.currentPreset = ColorPreset.defaultPresets[0]
        }

        // カスタムプリセットを読み込む
        if let data = UserDefaults.standard.data(forKey: customPresetsKey),
           let presets = try? JSONDecoder().decode([ColorPreset].self, from: data) {
            self.customPresets = presets
        } else {
            self.customPresets = []
        }

        // 外観モードを読み込む
        let modeRawValue = UserDefaults.standard.integer(forKey: appearanceModeKey)
        self.appearanceMode = AppAppearanceMode(rawValue: modeRawValue) ?? .system
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(currentPreset) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: customPresetsKey)
        }
    }

    func addCustomPreset(_ preset: ColorPreset) {
        customPresets.append(preset)
    }

    func removeCustomPreset(_ preset: ColorPreset) {
        customPresets.removeAll { $0.id == preset.id }
    }

    func updateCustomPreset(_ preset: ColorPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        }
    }

    var allPresets: [ColorPreset] {
        ColorPreset.defaultPresets + customPresets
    }
}
