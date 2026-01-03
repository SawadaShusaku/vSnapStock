//
//  CameraManager.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import AVFoundation
import UIKit
import Observation

/// カメラセッションの管理とOCR結果の保持を担当
@Observable
@MainActor
final class CameraManager: NSObject {

    // MARK: - Public State (SwiftUIから監視)

    private(set) var isSessionRunning = false
    private(set) var recognizedItems: [RecognizedTextItem] = []
    private(set) var detectedDate: Date?
    var selectedProductName: String?  // 編集可能
    var selectedDescription: String?  // 説明用
    private(set) var capturedImage: UIImage?

    var isFlashEnabled = false
    var isTorchEnabled = false
    var isDateScanEnabled = true
    var isProductNameScanEnabled = true
    var isDescriptionScanEnabled = false
    var currentZoomFactor: CGFloat = 1.0
    private(set) var maxZoomFactor: CGFloat = 5.0

    // MARK: - Internal

    let session = AVCaptureSession()
    private let recognitionService = TextRecognitionService()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?

    // 設定マネージャー
    private let ocrSettings = OCRSettingsManager.shared

    // スキャン制御
    private var lastScanTime: Date = .distantPast
    private var isProcessing = false
    private var hasNotifiedDate = false
    private var hasSelectedProductName = false
    private var hasSelectedDescription = false

    // セットアップ状態
    private var isSetupComplete = false

    // セッション管理用のキュー
    private let sessionQueue = DispatchQueue(label: "com.vSnapStock.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.vSnapStock.videoOutputQueue")

    // 撮影完了コールバック
    private var captureCompletion: ((UIImage?) -> Void)?

    // MARK: - Public Methods

    func startSession() async {
        guard await checkCameraPermission() else { return }

        // 既にセットアップ済みの場合はスキップ
        if !isSetupComplete {
            await setupCamera()
            isSetupComplete = true
        }

        // 既に実行中ならスキップ
        guard !session.isRunning else {
            isSessionRunning = true
            return
        }

        let captureSession = session
        sessionQueue.async {
            captureSession.startRunning()
        }
        isSessionRunning = true
    }

    func stopSession() {
        let captureSession = session
        sessionQueue.async {
            captureSession.stopRunning()
        }
        isSessionRunning = false
    }

    func capturePhoto() async -> UIImage? {
        guard let photoOutput = photoOutput else { return nil }

        return await withCheckedContinuation { continuation in
            captureCompletion = { image in
                continuation.resume(returning: image)
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = isFlashEnabled ? .on : .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func selectProductName(_ item: RecognizedTextItem) {
        hasSelectedProductName = true
        selectedProductName = item.text
    }

    func selectDescription(_ item: RecognizedTextItem) {
        hasSelectedDescription = true
        selectedDescription = item.text
    }

    func resetDateDetection() {
        hasNotifiedDate = false
        detectedDate = nil
    }

    func resetProductNameDetection() {
        hasSelectedProductName = false
        selectedProductName = nil
    }

    func resetDescriptionDetection() {
        hasSelectedDescription = false
        selectedDescription = nil
    }

    func resetAllDetection() {
        resetDateDetection()
        resetProductNameDetection()
        resetDescriptionDetection()
        recognizedItems = []
    }

    /// ズーム倍率を設定
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }

        let clampedFactor = max(1.0, min(factor, maxZoomFactor))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            currentZoomFactor = clampedFactor
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }

    /// ズーム倍率をトグル（1x ↔ 2x）
    func toggleZoom() {
        if currentZoomFactor < 1.5 {
            setZoom(2.0)
        } else {
            setZoom(1.0)
        }
    }

    /// トーチ（ライト）をトグル
    func toggleTorch() {
        guard let device = currentDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchEnabled = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchEnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle torch: \(error)")
        }
    }

    // MARK: - Private Methods

    private func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func setupCamera() async {
        session.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)
        currentDevice = backCamera
        maxZoomFactor = min(backCamera.activeFormat.videoMaxZoomFactor, 10.0)

        // 写真撮影用出力
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }

        // リアルタイムOCR用のビデオ出力
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        let result = await recognitionService.recognize(from: pixelBuffer)

        await MainActor.run {
            // 画面内のアイテムのみフィルタリング（正規化座標0-1の範囲内）
            let visibleItems = result.items.filter { item in
                let box = item.boundingBox
                return box.minX >= 0 && box.maxX <= 1 && box.minY >= 0 && box.maxY <= 1
            }

            // 日付検出
            if isDateScanEnabled, !hasNotifiedDate {
                if let dateItem = visibleItems.first(where: { $0.isDate }),
                   let extractedDate = dateItem.extractedDate {
                    hasNotifiedDate = true
                    detectedDate = extractedDate
                }
            }

            // テキストアイテム更新（表示数上限を適用）
            let maxCount = ocrSettings.maxDisplayCount
            let textScanEnabled = (isProductNameScanEnabled && !hasSelectedProductName) ||
                                  (isDescriptionScanEnabled && !hasSelectedDescription)

            if textScanEnabled {
                // テキスト選択前：すべて表示（上限あり）
                recognizedItems = Array(visibleItems.prefix(maxCount))
            } else {
                // テキスト選択後 or スキャン無効：日付のみ表示
                recognizedItems = Array(visibleItems.filter { $0.isDate }.prefix(maxCount))
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            // すべてのスキャンが無効ならスキップ
            guard isDateScanEnabled || isProductNameScanEnabled || isDescriptionScanEnabled else {
                recognizedItems = []
                return
            }

            // スキャン間隔をチェック（設定から取得）
            let now = Date()
            guard now.timeIntervalSince(lastScanTime) >= ocrSettings.scanInterval else { return }

            // 処理中の場合はスキップ
            guard !isProcessing else { return }

            lastScanTime = now
            isProcessing = true

            defer { isProcessing = false }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            await processFrame(pixelBuffer)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                captureCompletion?(nil)
                captureCompletion = nil
                return
            }

            capturedImage = image
            captureCompletion?(image)
            captureCompletion = nil
        }
    }
}
