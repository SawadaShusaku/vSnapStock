# Vision Framework 完全ガイド (2025年版)

## 目次
1. [概要](#概要)
2. [座標系の理解](#座標系の理解)
3. [iOS 17以前のAPI（従来のAPI）](#ios-17以前のapi従来のapi)
4. [iOS 18+ 新Swift API](#ios-18-新swift-api)
5. [座標変換の詳細](#座標変換の詳細)
6. [カメラプレビューでのバウンディングボックス表示](#カメラプレビューでのバウンディングボックス表示)
7. [ベストプラクティス](#ベストプラクティス)
8. [よくある問題と解決策](#よくある問題と解決策)
9. [参考資料](#参考資料)

---

## 概要

Vision Frameworkは、iOSで画像解析（OCR、顔検出、バーコード検出など）を行うためのApple公式フレームワークです。

### iOS 18での主な変更点（WWDC 2024）

- **VNプレフィックスの廃止**: `VNRecognizeTextRequest` → `RecognizeTextRequest`
- **async/await対応**: 完全なSwift Concurrencyサポート
- **新しい座標変換API**: `toImageCoordinates()` メソッドの追加
- **Swift 6対応**: より安全で効率的なコード

---

## 座標系の理解

### 1. Vision Framework の座標系
- **原点**: 左下 (bottom-left)
- **範囲**: 0.0 〜 1.0 (正規化座標)
- **方向**: X軸は右方向、Y軸は上方向

### 2. UIKit / SwiftUI の座標系
- **原点**: 左上 (top-left)
- **範囲**: ピクセル座標
- **方向**: X軸は右方向、Y軸は下方向

### 3. AVCaptureVideoPreviewLayer の座標系
- メタデータ出力座標は **左上原点** の正規化座標を期待
- `layerRectConverted(fromMetadataOutputRect:)` が回転とスケーリングを自動処理

### 座標系の図解

```
Vision座標系（左下原点）:          UIKit座標系（左上原点）:
┌─────────────────┐               ┌─────────────────┐
│            (1,1)│               │(0,0)            │
│                 │               │                 │
│    ┌───┐        │               │    ┌───┐        │
│    │TXT│        │      ───→     │    │TXT│        │
│    └───┘        │               │    └───┘        │
│                 │               │                 │
│(0,0)            │               │            (1,1)│
└─────────────────┘               └─────────────────┘
```

---

## iOS 17以前のAPI（従来のAPI）

### 基本的なテキスト認識

```swift
import Vision

func recognizeText(in image: UIImage) {
    guard let cgImage = image.cgImage else { return }

    // 1. リクエストを作成
    let request = VNRecognizeTextRequest { request, error in
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

        for observation in observations {
            // テキストを取得（上位1候補）
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            print("認識テキスト: \(topCandidate.string)")
            print("信頼度: \(topCandidate.confidence)")
            print("バウンディングボックス: \(observation.boundingBox)")
        }
    }

    // 2. リクエストの設定
    request.recognitionLevel = .accurate  // .fast または .accurate
    request.recognitionLanguages = ["ja-JP", "en-US"]  // 日本語と英語
    request.usesLanguageCorrection = true  // 言語補正を有効化

    // 3. リクエストを実行
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        print("エラー: \(error)")
    }
}
```

### 認識レベルの選択

| レベル | 特徴 | ユースケース |
|--------|------|--------------|
| `.accurate` | 高精度、低速 | 静止画像、文書スキャン |
| `.fast` | 低精度、高速 | リアルタイムカメラ、機械可読コード（MRZ） |

### リアルタイムカメラでの使用

```swift
// AVCaptureVideoDataOutputSampleBufferDelegate での実装
func captureOutput(_ output: AVCaptureOutput,
                   didOutput sampleBuffer: CMSampleBuffer,
                   from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    let request = VNRecognizeTextRequest { request, error in
        // 結果処理
    }
    request.recognitionLevel = .fast  // リアルタイムでは.fastを推奨

    // 向きを指定（重要！）
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                         orientation: .right,  // カメラの向きに応じて調整
                                         options: [:])
    try? handler.perform([request])
}
```

---

## iOS 18+ 新Swift API

### 基本的なテキスト認識（async/await）

```swift
import Vision

@available(iOS 18.0, *)
func recognizeText(in image: UIImage) async throws -> [String] {
    guard let cgImage = image.cgImage else { return [] }

    // 1. リクエストを作成
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = [
        Locale.Language(identifier: "ja"),  // 日本語優先
        Locale.Language(identifier: "en")
    ]
    request.usesLanguageCorrection = true

    // 2. ハンドラーを作成して実行
    let handler = ImageRequestHandler(cgImage)
    let observations = try await handler.perform(request)

    // 3. 結果を処理
    return observations.compactMap { observation in
        observation.topCandidates(1).first?.string
    }
}
```

### 新しい座標変換API: `toImageCoordinates()`

```swift
@available(iOS 18.0, *)
func getTextBoundingBoxes(in image: UIImage) async throws -> [CGRect] {
    guard let cgImage = image.cgImage else { return [] }

    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

    var request = RecognizeTextRequest()
    let handler = ImageRequestHandler(cgImage)
    let observations = try await handler.perform(request)

    return observations.map { observation in
        // 正規化座標 → 画像座標に変換
        // origin: .upperLeft で左上原点に変換
        observation.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
    }
}
```

### 複数リクエストの同時実行

```swift
@available(iOS 18.0, *)
func performMultipleRequests(on image: CGImage) async throws {
    let textRequest = RecognizeTextRequest()
    let barcodeRequest = DetectBarcodesRequest()

    let handler = ImageRequestHandler(image)

    // 両方の結果を待つ
    let (textResults, barcodeResults) = try await handler.perform(textRequest, barcodeRequest)

    // または、結果をストリーミングで取得
    for try await result in handler.performAll(textRequest, barcodeRequest) {
        switch result {
        case let textObs as RecognizedTextObservation:
            print("テキスト検出: \(textObs.topCandidates(1).first?.string ?? "")")
        case let barcodeObs as BarcodeObservation:
            print("バーコード検出: \(barcodeObs.payloadStringValue ?? "")")
        default:
            break
        }
    }
}
```

### 並列処理の最適化

```swift
@available(iOS 18.0, *)
func processBatchImages(_ images: [UIImage]) async throws -> [[String]] {
    // 注意: 同時に2つ以上のRecognizeTextRequestを並列実行すると
    // デッドロックが発生する可能性があるため、制限が必要

    var results: [[String]] = []

    // 最大2つまで並列実行
    for chunk in images.chunked(into: 2) {
        try await withThrowingTaskGroup(of: [String].self) { group in
            for image in chunk {
                group.addTask {
                    try await self.recognizeText(in: image)
                }
            }
            for try await result in group {
                results.append(result)
            }
        }
    }

    return results
}
```

---

## 座標変換の詳細

### 変換の基本式

**Vision座標（左下原点）→ UIKit座標（左上原点）**

```swift
// Y軸を反転
let uiKitRect = CGRect(
    x: visionRect.origin.x,
    y: 1 - visionRect.origin.y - visionRect.height,
    width: visionRect.width,
    height: visionRect.height
)
```

### 正規化座標 → ピクセル座標

```swift
// VNImageRectForNormalizedRect を使用
let pixelRect = VNImageRectForNormalizedRect(
    normalizedRect,  // Vision の正規化座標
    Int(imageWidth),
    Int(imageHeight)
)
```

### AVCaptureVideoPreviewLayer での変換

```swift
func convertVisionRectToPreviewLayer(
    _ visionRect: CGRect,
    previewLayer: AVCaptureVideoPreviewLayer
) -> CGRect {
    // Step 1: Y軸を反転（Vision座標 → メタデータ座標）
    let normalizedRect = CGRect(
        x: visionRect.origin.x,
        y: 1 - visionRect.origin.y - visionRect.height,
        width: visionRect.width,
        height: visionRect.height
    )

    // Step 2: プレビューレイヤーの座標に変換
    // この関数が回転とスケーリングを自動処理
    return previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect)
}
```

### iOS 18+ での座標変換

```swift
@available(iOS 18.0, *)
func convertBoundingBox(
    _ observation: RecognizedTextObservation,
    to viewSize: CGSize
) -> CGRect {
    // 新APIを使用して直接変換
    return observation.boundingBox.toImageCoordinates(viewSize, origin: .upperLeft)
}
```

---

## カメラプレビューでのバウンディングボックス表示

### 完全な実装例

```swift
import SwiftUI
import AVFoundation
import Vision

class TextRecognitionManager: NSObject, ObservableObject {
    @Published var boundingBoxes: [CGRect] = []
    @Published var recognizedTexts: [String] = []

    private var previewLayer: AVCaptureVideoPreviewLayer?

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = layer
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var boxes: [CGRect] = []
            var texts: [String] = []

            for observation in observations {
                guard let text = observation.topCandidates(1).first?.string else { continue }

                // Vision座標をプレビューレイヤー座標に変換
                if let layerRect = self.convertToLayerRect(observation.boundingBox) {
                    boxes.append(layerRect)
                    texts.append(text)
                }
            }

            DispatchQueue.main.async {
                self.boundingBoxes = boxes
                self.recognizedTexts = texts
            }
        }

        request.recognitionLevel = .fast
        request.recognitionLanguages = ["ja-JP", "en-US"]

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,  // ポートレートモードの場合
            options: [:]
        )

        try? handler.perform([request])
    }

    private func convertToLayerRect(_ visionRect: CGRect) -> CGRect? {
        guard let previewLayer = previewLayer else { return nil }

        // Y軸反転のみ（layerRectConvertedが回転を処理）
        let normalizedRect = CGRect(
            x: visionRect.origin.x,
            y: 1 - visionRect.origin.y - visionRect.height,
            width: visionRect.width,
            height: visionRect.height
        )

        return previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect)
    }
}
```

### SwiftUI でのオーバーレイ表示

```swift
struct BoundingBoxOverlay: View {
    let boxes: [CGRect]
    let texts: [String]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(zip(boxes, texts).enumerated()), id: \.offset) { index, item in
                let (box, text) = item

                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)

                Text(text)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .position(x: box.midX, y: box.minY - 10)
            }
        }
    }
}
```

---

## ベストプラクティス

### 1. 認識レベルの適切な選択

```swift
// リアルタイムカメラ → .fast
request.recognitionLevel = .fast

// 静止画像・文書スキャン → .accurate
request.recognitionLevel = .accurate
```

### 2. 言語設定の最適化

```swift
// 対象言語を明示的に指定すると精度向上
request.recognitionLanguages = ["ja-JP", "en-US"]

// カスタム単語を追加（専門用語など）
request.customWords = ["vSnapStock", "OCR"]

// 機械可読コード（MRZ）では言語補正を無効化
request.usesLanguageCorrection = false  // MRZの場合
```

### 3. パフォーマンス最適化

```swift
// 小さいテキストを無視
request.minimumTextHeight = 0.05  // 画像高さの5%未満を無視

// リアルタイム処理ではフレームをスキップ
private var isProcessing = false

func captureOutput(...) {
    guard !isProcessing else { return }  // 処理中はスキップ
    isProcessing = true

    // 処理後
    isProcessing = false
}
```

### 4. 向きの正しい指定

```swift
// カメラからの入力には向きを指定
let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: .right,  // ポートレートモードでは .right
    options: [:]
)

// 静止画像には画像の向きを使用
let handler = VNImageRequestHandler(
    cgImage: cgImage,
    orientation: CGImagePropertyOrientation(image.imageOrientation),
    options: [:]
)
```

### 5. iOS バージョン分岐

```swift
func recognizeText(in image: UIImage) async throws -> [String] {
    guard let cgImage = image.cgImage else { return [] }

    if #available(iOS 18.0, *) {
        // 新APIを使用
        var request = RecognizeTextRequest()
        let handler = ImageRequestHandler(cgImage)
        let observations = try await handler.perform(request)
        return observations.compactMap { $0.topCandidates(1).first?.string }
    } else {
        // 従来のAPIを使用
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: results)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

---

## よくある問題と解決策

### 問題1: バウンディングボックスの位置がずれる

**原因**: Y軸の反転を忘れている、または二重に回転を適用している

**解決策**:
```swift
// ✅ 正しい: Y軸反転のみ
let normalizedRect = CGRect(
    x: visionRect.origin.x,
    y: 1 - visionRect.origin.y - visionRect.height,
    width: visionRect.width,
    height: visionRect.height
)

// ❌ 間違い: 手動で回転を適用（layerRectConvertedが既に処理する）
let wrongRect = CGRect(
    x: 1 - rect.origin.y - rect.height,
    y: rect.origin.x,
    width: rect.height,
    height: rect.width
)
```

### 問題2: 横長テキストが縦長ボックスになる

**原因**: width と height を入れ替えている

**解決策**: Y軸反転のみ行い、width/height はそのまま維持

### 問題3: カメラ映像でテキストが認識されない

**原因**: 向きの指定が間違っている

**解決策**:
```swift
// ポートレートモードの場合
let handler = VNImageRequestHandler(
    cvPixelBuffer: pixelBuffer,
    orientation: .right,  // または .left（フロントカメラ）
    options: [:]
)
```

### 問題4: iOS 18で並列処理がハングする

**原因**: RecognizeTextRequest の並列実行数が多すぎる

**解決策**: 同時実行数を2以下に制限
```swift
// 最大2つまで並列実行
for chunk in images.chunked(into: 2) {
    // 処理
}
```

### 問題5: 認識精度が低い

**解決策**:
```swift
// 1. 認識レベルを .accurate に
request.recognitionLevel = .accurate

// 2. 対象言語を明示的に指定
request.recognitionLanguages = ["ja-JP"]

// 3. カスタム単語を追加
request.customWords = ["専門用語1", "専門用語2"]

// 4. 言語補正を有効化
request.usesLanguageCorrection = true
```

---

## 参考資料

### Apple 公式ドキュメント
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [VNRecognizedTextObservation](https://developer.apple.com/documentation/vision/vnrecognizedtextobservation)
- [AVCaptureVideoPreviewLayer](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)

### WWDC セッション
- [Discover Swift enhancements in the Vision framework - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [Extract document data using Vision - WWDC21](https://developer.apple.com/videos/play/wwdc2021/10041/)

### チュートリアル・記事
- [Recognizing text with the Vision framework - Create with Swift](https://www.createwithswift.com/recognizing-text-with-the-vision-framework/)
- [How to display Vision bounding boxes - Machine Think](https://machinethink.net/blog/bounding-boxes/)
- [Vision Framework in Swift for iOS Development [2025 Edition] - Bitcot](https://www.bitcot.com/vision-framework-in-swift-for-ios-development/)
- [Hacking with Swift - VNRecognizeTextRequest OCR](https://www.hackingwithswift.com/example-code/vision/how-to-use-vnrecognizetextrequests-optical-character-recognition-to-detect-text-in-an-image)

---

## 検証チェックリスト

バウンディングボックスが正しく表示されているか確認するためのチェックリスト:

1. [ ] 横長のテキスト（例: "2025.12.28"）を認識させる
2. [ ] バウンディングボックスが横長で表示されることを確認
3. [ ] ボックスがテキストの位置と一致することを確認
4. [ ] 画面の四隅でテキストを認識させ、位置がずれないことを確認
5. [ ] 端末を回転させてもボックスが正しく表示されることを確認
