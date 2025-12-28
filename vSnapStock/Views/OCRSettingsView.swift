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
                            Text("表示数上限")
                            Spacer()
                            Text("\(settings.maxDisplayCount)件")
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
                            Text("スキャン間隔")
                            Spacer()
                            Text(String(format: "%.1f秒", settings.scanInterval))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $settings.scanInterval,
                            in: 0.5...3.0,
                            step: 0.5
                        )
                    }
                } header: {
                    Text("表示設定")
                } footer: {
                    Text("表示数を減らすとバウンディングボックスが見やすくなります")
                }

                // フィルタリング設定
                Section {
                    Toggle("小さなテキストを無視", isOn: $settings.filterSmallText)

                    if settings.filterSmallText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("最小面積")
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
                    Text("フィルタリング")
                } footer: {
                    Text("画面の一定割合未満の小さなテキストを除外します")
                }

                // 横書きテキスト結合（縦方向マージ）
                Section {
                    Toggle("横書きテキストを結合", isOn: $settings.mergeNearbyText)

                    if settings.mergeNearbyText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("結合距離（縦方向）")
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
                    Text("横書きテキスト結合")
                } footer: {
                    Text("縦方向に近いテキストを1つのボックスにまとめます")
                }

                // 縦書きテキスト結合（横方向マージ）
                Section {
                    Toggle("縦書きテキストを結合", isOn: $settings.mergeVerticalText)

                    if settings.mergeVerticalText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("結合距離（横方向）")
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
                    Text("縦書きテキスト結合")
                } footer: {
                    Text("横方向に近いテキストを1つのボックスにまとめます（縦書き商品名用）")
                }

                // リセット
                Section {
                    Button(role: .destructive) {
                        settings.resetToDefaults()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("デフォルトに戻す")
                        }
                    }
                }
            }
            .navigationTitle("OCR設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
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
