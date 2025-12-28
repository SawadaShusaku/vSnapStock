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
    private(set) var selectedProductName: String?
    private(set) var capturedImage: UIImage?

    var isFlashEnabled = false
    var isDateScanEnabled = true
    var isProductNameScanEnabled = true

    // MARK: - Internal

    let session = AVCaptureSession()
    private let recognitionService = TextRecognitionService()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?

    // 設定マネージャー
    private let ocrSettings = OCRSettingsManager.shared

    // スキャン制御
    private var lastScanTime: Date = .distantPast
    private var isProcessing = false
    private var hasNotifiedDate = false
    private var hasSelectedProductName = false

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

    func resetDateDetection() {
        hasNotifiedDate = false
        detectedDate = nil
    }

    func resetProductNameDetection() {
        hasSelectedProductName = false
        selectedProductName = nil
    }

    func resetAllDetection() {
        resetDateDetection()
        resetProductNameDetection()
        recognizedItems = []
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
            if isProductNameScanEnabled && !hasSelectedProductName {
                // 商品名選択前：すべて表示（上限あり）
                recognizedItems = Array(visibleItems.prefix(maxCount))
            } else if hasSelectedProductName {
                // 商品名選択後：日付のみ表示（選択した商品名はステータスに表示）
                recognizedItems = Array(visibleItems.filter { $0.isDate }.prefix(maxCount))
            } else if !isProductNameScanEnabled {
                // 商品名スキャン無効：日付のみ表示
                recognizedItems = Array(visibleItems.filter { $0.isDate }.prefix(maxCount))
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            // 両方のスキャンが無効ならスキップ
            guard isDateScanEnabled || isProductNameScanEnabled else {
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
