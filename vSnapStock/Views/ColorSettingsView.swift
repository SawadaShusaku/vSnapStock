//
//  ColorSettingsView.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct ColorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var colorManager = ColorSettingsManager.shared
    @State private var showingCustomColorEditor = false
    @State private var editingPreset: ColorPreset?
    @State private var isBasicPresetsExpanded = true
    @State private var isGradientPresetsExpanded = true
    @State private var isCustomPresetsExpanded = true

    var body: some View {
        NavigationStack {
            List {
                // 外観モード
                Section {
                    Picker("外観モード", selection: $colorManager.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("外観モード")
                } footer: {
                    Text("アプリ全体のライト/ダークモードを切り替えます")
                }

                // 基本プリセット（折りたたみ可能）
                Section {
                    DisclosureGroup(isExpanded: $isBasicPresetsExpanded) {
                        ForEach(ColorPreset.defaultPresets) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: colorManager.currentPreset.id == preset.id,
                                onSelect: {
                                    colorManager.currentPreset = preset
                                }
                            )
                            .contextMenu {
                                Button {
                                    // プリセットをベースに新しいカスタムプリセットとして編集
                                    var editablePreset = preset
                                    editablePreset = ColorPreset(
                                        id: UUID(),
                                        name: "\(preset.name)（カスタム）",
                                        cardColor: preset.cardColor,
                                        backgroundColor: preset.backgroundColor,
                                        backgroundGradient: preset.backgroundGradient,
                                        cardGradient: preset.cardGradient
                                    )
                                    editingPreset = editablePreset
                                } label: {
                                    Label("編集してカスタム作成", systemImage: "pencil")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(.blue)
                            Text("基本プリセット")
                                .font(.headline)
                        }
                    }
                }

                // グラデーションプリセット（折りたたみ可能）
                Section {
                    DisclosureGroup(isExpanded: $isGradientPresetsExpanded) {
                        ForEach(ColorPreset.gradientPresets) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: colorManager.currentPreset.id == preset.id,
                                onSelect: {
                                    colorManager.currentPreset = preset
                                }
                            )
                            .contextMenu {
                                Button {
                                    // プリセットをベースに新しいカスタムプリセットとして編集
                                    var editablePreset = preset
                                    editablePreset = ColorPreset(
                                        id: UUID(),
                                        name: "\(preset.name)（カスタム）",
                                        cardColor: preset.cardColor,
                                        backgroundColor: preset.backgroundColor,
                                        backgroundGradient: preset.backgroundGradient,
                                        cardGradient: preset.cardGradient
                                    )
                                    editingPreset = editablePreset
                                } label: {
                                    Label("編集してカスタム作成", systemImage: "pencil")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.stack.3d.down.forward.fill")
                                .foregroundColor(.purple)
                            Text("グラデーション")
                                .font(.headline)
                        }
                    }
                }

                // カスタムプリセット（折りたたみ可能）
                Section {
                    DisclosureGroup(isExpanded: $isCustomPresetsExpanded) {
                        ForEach(colorManager.customPresets) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: colorManager.currentPreset.id == preset.id,
                                onSelect: {
                                    colorManager.currentPreset = preset
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    colorManager.removeCustomPreset(preset)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }

                                Button {
                                    editingPreset = preset
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }

                        Button {
                            showingCustomColorEditor = true
                        } label: {
                            Label("カスタムカラーを追加", systemImage: "plus.circle")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.orange)
                            Text("カスタム")
                                .font(.headline)
                        }
                    }
                }

                // プレビュー
                Section("プレビュー") {
                    PreviewCard()
                        .listRowBackground(
                            Group {
                                if let gradient = colorManager.backgroundGradient {
                                    gradient
                                } else {
                                    colorManager.backgroundColor
                                }
                            }
                        )
                }
            }
            .navigationTitle("カラー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomColorEditor) {
                CustomColorEditorView(
                    preset: nil,
                    onSave: { newPreset in
                        colorManager.addCustomPreset(newPreset)
                        colorManager.currentPreset = newPreset
                    }
                )
            }
            .sheet(item: $editingPreset) { preset in
                CustomColorEditorView(
                    preset: preset,
                    onSave: { updatedPreset in
                        // 既存のカスタムプリセットかどうかをチェック
                        if colorManager.customPresets.contains(where: { $0.id == updatedPreset.id }) {
                            colorManager.updateCustomPreset(updatedPreset)
                        } else {
                            // 新規カスタムプリセットとして追加
                            colorManager.addCustomPreset(updatedPreset)
                        }
                        colorManager.currentPreset = updatedPreset
                    }
                )
            }
        }
    }
}

// MARK: - Preset Row
struct PresetRow: View {
    let preset: ColorPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // カラープレビュー
                HStack(spacing: 4) {
                    // カードカラー
                    RoundedRectangle(cornerRadius: 4)
                        .fill(preset.cardColor.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    // 背景カラー（グラデーションがある場合はグラデーション表示）
                    if let gradient = preset.backgroundGradient, gradient.isEnabled {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(gradient.gradient)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(preset.backgroundColor.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                Text(preset.name)
                    .foregroundColor(.primary)

                if preset.hasGradient {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Preview Card
struct PreviewCard: View {
    @State private var colorManager = ColorSettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 80)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }

            Text("サンプルカード")
                .font(.headline)

            Text("賞味期限: 2025/01/15")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(colorManager.cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Custom Color Editor
struct CustomColorEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let preset: ColorPreset?
    let onSave: (ColorPreset) -> Void

    @State private var name: String = ""
    @State private var cardColor: Color = .white
    @State private var backgroundColor: Color = Color(.systemGray6)
    @State private var useGradient: Bool = false
    @State private var gradientStartColor: Color = .blue
    @State private var gradientEndColor: Color = .purple
    @State private var gradientAngle: Double = 180

    private var isEditing: Bool { preset != nil }

    private var backgroundView: some View {
        Group {
            if useGradient {
                LinearGradient(
                    colors: [gradientStartColor, gradientEndColor],
                    startPoint: gradientStartPoint,
                    endPoint: gradientEndPoint
                )
            } else {
                backgroundColor
            }
        }
    }

    private var gradientStartPoint: UnitPoint {
        let radians = gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 - cos(radians) * 0.5, y: 0.5 - sin(radians) * 0.5)
    }

    private var gradientEndPoint: UnitPoint {
        let radians = gradientAngle * .pi / 180
        return UnitPoint(x: 0.5 + cos(radians) * 0.5, y: 0.5 + sin(radians) * 0.5)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("プリセット名", text: $name)
                }

                Section("カードの色") {
                    ColorPicker("カードカラー", selection: $cardColor, supportsOpacity: true)

                    // RGBAスライダー
                    RGBASliders(color: $cardColor)
                }

                Section("背景") {
                    Toggle("グラデーションを使用", isOn: $useGradient)

                    if useGradient {
                        ColorPicker("開始色", selection: $gradientStartColor, supportsOpacity: true)
                        ColorPicker("終了色", selection: $gradientEndColor, supportsOpacity: true)

                        VStack(alignment: .leading) {
                            HStack {
                                Text("角度")
                                Spacer()
                                Text("\(Int(gradientAngle))°")
                            }
                            Slider(value: $gradientAngle, in: 0...360, step: 15)
                        }
                    } else {
                        ColorPicker("背景カラー", selection: $backgroundColor, supportsOpacity: true)

                        // RGBAスライダー
                        RGBASliders(color: $backgroundColor)
                    }
                }

                Section("プレビュー") {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 60)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }

                        Text("サンプル")
                            .font(.headline)
                    }
                    .padding(12)
                    .background(cardColor)
                    .cornerRadius(12)
                    .listRowBackground(backgroundView)
                }
            }
            .navigationTitle(isEditing ? "カラーを編集" : "カスタムカラー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var backgroundGradient: GradientSettings? = nil
                        if useGradient {
                            backgroundGradient = GradientSettings(
                                isEnabled: true,
                                startColor: RGBAColor(color: gradientStartColor),
                                endColor: RGBAColor(color: gradientEndColor),
                                angle: gradientAngle
                            )
                        }

                        let newPreset = ColorPreset(
                            id: preset?.id ?? UUID(),
                            name: name.isEmpty ? "カスタム" : name,
                            cardColor: RGBAColor(color: cardColor),
                            backgroundColor: RGBAColor(color: backgroundColor),
                            backgroundGradient: backgroundGradient
                        )
                        onSave(newPreset)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let preset = preset {
                    name = preset.name
                    cardColor = preset.cardColor.color
                    backgroundColor = preset.backgroundColor.color

                    // グラデーション設定を読み込む
                    if let gradient = preset.backgroundGradient, gradient.isEnabled {
                        useGradient = true
                        gradientStartColor = gradient.startColor.color
                        gradientEndColor = gradient.endColor.color
                        gradientAngle = gradient.angle
                    }
                }
            }
        }
    }
}

// MARK: - RGBA Sliders
struct RGBASliders: View {
    @Binding var color: Color

    @State private var red: Double = 0
    @State private var green: Double = 0
    @State private var blue: Double = 0
    @State private var alpha: Double = 1

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("R")
                    .frame(width: 20)
                Slider(value: $red, in: 0...1)
                    .tint(.red)
                Text("\(Int(red * 255))")
                    .frame(width: 40)
            }

            HStack {
                Text("G")
                    .frame(width: 20)
                Slider(value: $green, in: 0...1)
                    .tint(.green)
                Text("\(Int(green * 255))")
                    .frame(width: 40)
            }

            HStack {
                Text("B")
                    .frame(width: 20)
                Slider(value: $blue, in: 0...1)
                    .tint(.blue)
                Text("\(Int(blue * 255))")
                    .frame(width: 40)
            }

            HStack {
                Text("A")
                    .frame(width: 20)
                Slider(value: $alpha, in: 0...1)
                    .tint(.gray)
                Text("\(Int(alpha * 100))%")
                    .frame(width: 40)
            }
        }
        .font(.caption)
        .onChange(of: red) { updateColor() }
        .onChange(of: green) { updateColor() }
        .onChange(of: blue) { updateColor() }
        .onChange(of: alpha) { updateColor() }
        .onAppear { loadColor() }
        .onChange(of: color) { loadColor() }
    }

    private func loadColor() {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }

    private func updateColor() {
        color = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

#Preview {
    ColorSettingsView()
}
