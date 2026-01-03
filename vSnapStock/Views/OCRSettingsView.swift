//
//  OCRSettingsView.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct OCRSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = OCRSettingsManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // 表示設定
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(localized: "ocr.display_limit"))
                            Spacer()
                            Text("\(settings.maxDisplayCount)" + String(localized: "ocr.items"))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.maxDisplayCount) },
                                set: { settings.maxDisplayCount = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(localized: "ocr.scan_interval"))
                            Spacer()
                            Text(String(format: "%.1f", settings.scanInterval) + String(localized: "ocr.seconds"))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.scanInterval,
                            in: 0.5...3.0,
                            step: 0.5
                        )
                    }
                } header: {
                    Text(String(localized: "ocr.display_settings"))
                } footer: {
                    Text(String(localized: "ocr.display_settings_footer"))
                }

                // フィルタリング設定
                Section {
                    Toggle(String(localized: "ocr.ignore_small_text"), isOn: $settings.filterSmallText)

                    if settings.filterSmallText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(localized: "ocr.minimum_area"))
                                Spacer()
                                Text(String(format: "%.1f%%", settings.minAreaThreshold))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: $settings.minAreaThreshold,
                                in: 0.1...5.0,
                                step: 0.1
                            )
                        }
                    }
                } header: {
                    Text(String(localized: "ocr.filtering"))
                } footer: {
                    Text(String(localized: "ocr.minimum_area_footer"))
                }

                // 横書きテキスト結合（縦方向マージ）
                Section {
                    Toggle(String(localized: "ocr.merge_horizontal"), isOn: $settings.mergeNearbyText)

                    if settings.mergeNearbyText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(localized: "ocr.merge_distance_vertical"))
                                Spacer()
                                Text(String(format: "%.1f%%", settings.mergeThreshold))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: $settings.mergeThreshold,
                                in: 0.5...10.0,
                                step: 0.5
                            )
                        }
                    }
                } header: {
                    Text(String(localized: "ocr.merge_horizontal"))
                } footer: {
                    Text(String(localized: "ocr.merge_horizontal_footer"))
                }

                // 縦書きテキスト結合（横方向マージ）
                Section {
                    Toggle(String(localized: "ocr.merge_vertical"), isOn: $settings.mergeVerticalText)

                    if settings.mergeVerticalText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(localized: "ocr.merge_distance_horizontal"))
                                Spacer()
                                Text(String(format: "%.1f%%", settings.verticalTextMergeThreshold))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: $settings.verticalTextMergeThreshold,
                                in: 0.5...10.0,
                                step: 0.5
                            )
                        }
                    }
                } header: {
                    Text(String(localized: "ocr.merge_vertical"))
                } footer: {
                    Text(String(localized: "ocr.merge_vertical_footer"))
                }

                // リセット
                Section {
                    Button(role: .destructive) {
                        settings.resetToDefaults()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(String(localized: "button.reset_default"))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "menu.ocr_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OCRSettingsView()
}
