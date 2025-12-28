# PhotoCapture リファクタリング設計書

## 1. 概要

### 1.1 目的
`PhotoCaptureSheet.swift` および `DateTextRecognizer.swift` をSwift/SwiftUIのベストプラクティスに則ってリファクタリングし、保守性・可読性を向上させる。

### 1.2 ターゲット環境
- iOS 18.0+
- Swift 6
- SwiftUI + 新Vision API

---

## 2. 現状の問題点

### 2.1 責務の混在

`CameraViewController` が以下の全てを担当しており、巨大化している：

- AVCaptureSession の管理
- 写真撮影
- リアルタイムOCR処理の呼び出し
- CALayerによるバウンディングボックス描画
- タップジェスチャー処理
- 座標変換

### 2.2 UIKitとSwiftUIの状態分断

```swift
// SwiftUI側
@State private var isFlashOn = false

// UIViewController側（別の状態）
var isFlashOn = false
```

同じ状態が二重管理されており、同期が必要になっている。

### 2.3 NotificationCenterの使用

```swift
// シャッターボタン
NotificationCenter.default.post(name: .capturePhoto, object: nil)
```

型安全性がなく、追跡が困難。

### 2.4 手動ロック

```swift
private let processingLock = NSLock()
private var _isProcessing = false
```

Actorを使えば不要。

### 2.5 Vision APIの使い方

現在 `ImageRequestHandler` を使用しているが、iOS 18+では不要。

---

## 3. リファクタリング方針

### 3.1 分離する責務

現在の2ファイルを **3-4ファイル** に分離する：

| コンポーネント | 責務 |
|---------------|------|
| **CameraManager** | カメラセッション管理、撮影、フレーム取得 |
| **TextRecognitionService** | Vision APIによるOCR処理 |
| **Models** | RecognizedTextItem, OCRResult 等のデータ型 |
| **PhotoCaptureSheet** | UI構成、状態管理、描画 |

### 3.2 技術選択

| 現状 | 変更後 |
|------|--------|
| NSLock | Actor |
| NotificationCenter | コールバック / async-await |
| CALayer描画 | SwiftUI Overlay |
| @State × UIViewController二重管理 | @Observable 一元管理 |
| ImageRequestHandler | request.perform(on:) 直接実行 |

---

## 4. コンポーネント設計

### 4.1 Models

認識結果を表すデータ型。現在の `DateTextRecognizer.swift` 上部にある定義を分離。

```swift
enum TextType: Equatable, Sendable {
    case date(Date)
    case productNameCandidate
    case general
}

struct RecognizedTextItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let boundingBox: CGRect  // 正規化座標（0-1、左下原点）
    let textType: TextType
    
    var isDate: Bool { ... }
    var extractedDate: Date? { ... }
}

struct OCRResult: Sendable {
    let items: [RecognizedTextItem]
    var dateItem: RecognizedTextItem? { ... }
}
```

---

### 4.2 TextRecognitionService (Actor)

Vision APIによるOCR処理を担当。

```swift
actor TextRecognitionService {
    
    /// リアルタイム認識（カメラフレーム用）
    func recognize(from pixelBuffer: CVPixelBuffer) async -> OCRResult
    
    /// 静止画認識（撮影後の画像用）
    func recognize(from image: UIImage) async -> OCRResult
}
```

**内部実装のポイント:**

```swift
// iOS 18+ 推奨パターン（ImageRequestHandler不要）
var request = RecognizeTextRequest()
request.recognitionLanguages = [
    Locale.Language(identifier: "ja-JP"),
    Locale.Language(identifier: "en-US")
]
request.automaticallyDetectsLanguage = true
request.recognitionLevel = .accurate  // ⚠️ 日本語は .accurate 必須

let observations = try await request.perform(on: pixelBuffer)
```

> **注意**: `.fast`モードはラテン文字系のみ対応。日本語・中国語・韓国語などCJK文字を認識するには`.accurate`が必須。

**日付抽出・商品名判定ロジック** は現在の実装をそのまま移行。

---

### 4.3 CameraManager (@Observable)

カメラセッションの管理と、OCR結果の保持を担当。

```swift
@Observable
@MainActor
final class CameraManager: NSObject {
    
    // MARK: - 公開状態（SwiftUIから監視）
    
    private(set) var isSessionRunning = false
    private(set) var recognizedItems: [RecognizedTextItem] = []
    private(set) var detectedDate: Date?
    private(set) var selectedProductName: String?
    
    var isFlashEnabled = false
    var isDateScanEnabled = true
    var isProductNameScanEnabled = true
    
    // MARK: - 内部
    
    let session = AVCaptureSession()
    private let recognitionService = TextRecognitionService()
    
    // MARK: - 公開メソッド
    
    func startSession() async
    func stopSession()
    func capturePhoto() async -> UIImage?
    func selectProductName(_ item: RecognizedTextItem)
    func resetDetection()
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate { ... }
extension CameraManager: AVCapturePhotoCaptureDelegate { ... }
```

**設計ポイント:**
- `@Observable` によりSwiftUIと自然に統合
- `@MainActor` でスレッド安全性を保証
- 状態の二重管理を解消

---

### 4.4 PhotoCaptureSheet (SwiftUI)

UIの構成と、ユーザー操作のハンドリング。

```swift
struct PhotoCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photos: [Data]
    
    @State private var cameraManager = CameraManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraPreviewWithOverlay
                capturedPhotosStrip
                Spacer()
                recognitionSettings
                controlButtons
            }
            .task { await cameraManager.startSession() }
            .onDisappear { cameraManager.stopSession() }
        }
    }
    
    // カメラプレビュー + バウンディングボックス
    @ViewBuilder
    private var cameraPreviewWithOverlay: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
            boundingBoxOverlay
        }
    }
}
```

**バウンディングボックス描画:**

CALayerではなくSwiftUIで描画する。

```swift
@ViewBuilder
private var boundingBoxOverlay: some View {
    GeometryReader { geometry in
        ForEach(cameraManager.recognizedItems) { item in
            let rect = convertToViewCoordinates(item.boundingBox, in: geometry.size)
            
            RoundedRectangle(cornerRadius: 4)
                .stroke(item.isDate ? Color.green : Color.cyan, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .onTapGesture {
                    cameraManager.selectProductName(item)
                }
        }
    }
}
```

**CameraPreviewView** は最小限のUIViewRepresentable：

```swift
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

---

## 5. データフロー

```
┌──────────────────┐
│ AVCaptureOutput  │
│ (カメラフレーム)   │
└────────┬─────────┘
         │ CMSampleBuffer
         ▼
┌──────────────────┐
│  CameraManager   │
│  (Delegate)      │
└────────┬─────────┘
         │ CVPixelBuffer
         ▼
┌──────────────────┐
│ TextRecognition  │
│    Service       │
└────────┬─────────┘
         │ OCRResult
         ▼
┌──────────────────┐
│  CameraManager   │
│ .recognizedItems │ ← @Observable
└────────┬─────────┘
         │ SwiftUI自動更新
         ▼
┌──────────────────┐
│ BoundingBox      │
│   Overlay        │
└──────────────────┘
```

---

## 6. 座標変換

Visionの座標系は **左下原点・正規化(0-1)** なので、SwiftUI座標に変換が必要。

```swift
func convertToViewCoordinates(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
    CGRect(
        x: boundingBox.origin.x * size.width,
        y: (1 - boundingBox.origin.y - boundingBox.height) * size.height,
        width: boundingBox.width * size.width,
        height: boundingBox.height * size.height
    )
}
```

---

## 7. Vision API (iOS 18+) 正しい使い方

### ❌ 旧パターン（不要）

```swift
let handler = ImageRequestHandler(cgImage, orientation: orientation)
let observations = try await handler.perform(request)
```

### ✅ 新パターン（推奨）

```swift
var request = RecognizeTextRequest()
request.recognitionLanguages = [
    Locale.Language(identifier: "ja"),
    Locale.Language(identifier: "en")
]
request.automaticallyDetectsLanguage = true

// 直接実行（入力形式に応じて）
let observations = try await request.perform(on: pixelBuffer)
let observations = try await request.perform(on: cgImage)
let observations = try await request.perform(on: sampleBuffer)
let observations = try await request.perform(on: imageURL)
```

---

## 8. 変更のまとめ

| 項目 | Before | After |
|------|--------|-------|
| ファイル数 | 2 | 3-4 |
| 状態管理 | @State + UIViewController二重管理 | @Observable一元管理 |
| 並行処理 | NSLock | Actor |
| 通知 | NotificationCenter | コールバック / async |
| 描画 | CALayer (UIKit) | SwiftUI Overlay |
| Vision API | ImageRequestHandler経由 | request.perform(on:)直接 |
