//
//  PhotoCaptureSheet.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct PhotoCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photos: [Data]
    @Binding var recognizedDate: Date?
    var onDateRecognized: ((Date) -> Void)?
    var onProductNameRecognized: ((String) -> Void)?

    @State private var cameraManager = CameraManager()
    @State private var capturedImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []

    private let compressionQuality: CGFloat = 0.7
    private let maxPhotos = 10

    init(
        photos: Binding<[Data]>,
        recognizedDate: Binding<Date?> = .constant(nil),
        onDateRecognized: ((Date) -> Void)? = nil,
        onProductNameRecognized: ((String) -> Void)? = nil
    ) {
        self._photos = photos
        self._recognizedDate = recognizedDate
        self.onDateRecognized = onDateRecognized
        self.onProductNameRecognized = onProductNameRecognized
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraPreviewWithOverlay
                capturedPhotosStrip
                Spacer()
                recognitionSettings
                controlButtons
            }
            .background(Color(.systemBackground))
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        savePhotos()
                        dismiss()
                    }
                    .disabled(capturedImages.isEmpty)
                }
            }
            .task {
                await cameraManager.startSession()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
        }
    }

    // MARK: - Camera Preview with Overlay

    @ViewBuilder
    private var cameraPreviewWithOverlay: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
            boundingBoxOverlay

            // カメラ起動中はローディング表示
            if !cameraManager.isSessionRunning {
                Color.black.opacity(0.7)
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("カメラを起動中...")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    // MARK: - Bounding Box Overlay (SwiftUI)

    @ViewBuilder
    private var boundingBoxOverlay: some View {
        GeometryReader { geometry in
            ForEach(cameraManager.recognizedItems) { item in
                let rect = convertToViewCoordinates(item.boundingBox, in: geometry.size)

                // バウンディングボックス
                RoundedRectangle(cornerRadius: 4)
                    .stroke(boxColor(for: item), lineWidth: isSelected(item) ? 3 : 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(boxColor(for: item).opacity(isSelected(item) ? 0.3 : 0.1))
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture {
                        if !item.isDate && cameraManager.isProductNameScanEnabled {
                            cameraManager.selectProductName(item)
                        }
                    }

                // テキストラベル
                Text(labelText(for: item))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(boxColor(for: item).opacity(0.8))
                    .cornerRadius(4)
                    .position(x: rect.midX, y: max(rect.minY - 12, 10))
            }
        }
    }

    private func boxColor(for item: RecognizedTextItem) -> Color {
        if item.isDate {
            return .green
        } else if isSelected(item) {
            return .orange
        } else {
            return .cyan
        }
    }

    private func isSelected(_ item: RecognizedTextItem) -> Bool {
        cameraManager.selectedProductName == item.text
    }

    private func labelText(for item: RecognizedTextItem) -> String {
        let text = item.text
        if text.count > 15 {
            return String(text.prefix(15)) + "..."
        }
        return text
    }

    /// Vision座標（正規化・左下原点）をView座標に変換
    private func convertToViewCoordinates(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.origin.x * size.width,
            y: (1 - boundingBox.origin.y - boundingBox.height) * size.height,
            width: boundingBox.width * size.width,
            height: boundingBox.height * size.height
        )
    }

    // MARK: - Captured Photos Strip

    private var capturedPhotosStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capturedImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: capturedImages[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            capturedImages.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .font(.caption)
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                if capturedImages.isEmpty {
                    Text("撮影した写真がここに表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(height: 80)
        .background(Color(.systemGray6))
    }

    // MARK: - Recognition Settings

    private var recognitionSettings: some View {
        VStack(spacing: 8) {
            // 期限読取トグル
            Toggle(isOn: $cameraManager.isDateScanEnabled) {
                HStack {
                    Image(systemName: "calendar")
                    Text("期限を読取")
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal)
            .onChange(of: cameraManager.isDateScanEnabled) { _, newValue in
                if !newValue {
                    cameraManager.resetDateDetection()
                }
            }

            if cameraManager.isDateScanEnabled {
                dateStatusView
            }

            Divider()
                .padding(.horizontal)

            // 商品名読取トグル
            Toggle(isOn: $cameraManager.isProductNameScanEnabled) {
                HStack {
                    Image(systemName: "tag")
                    Text("商品名を読取")
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal)
            .onChange(of: cameraManager.isProductNameScanEnabled) { _, newValue in
                if !newValue {
                    cameraManager.resetProductNameDetection()
                }
            }

            if cameraManager.isProductNameScanEnabled {
                productNameStatusView
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var dateStatusView: some View {
        if let date = cameraManager.detectedDate {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(formatDate(date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Button {
                    cameraManager.resetDateDetection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        } else {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("日付を探しています...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var productNameStatusView: some View {
        if let name = cameraManager.selectedProductName {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.orange)
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Button {
                    cameraManager.resetProductNameDetection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        } else {
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(.orange)
                Text("テキストをタップして選択...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 40) {
            // フラッシュボタン
            Button {
                cameraManager.isFlashEnabled.toggle()
            } label: {
                Image(systemName: cameraManager.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundColor(cameraManager.isFlashEnabled ? .yellow : .gray)
                    .frame(width: 50, height: 50)
            }

            // シャッターボタン
            Button {
                Task {
                    if let image = await cameraManager.capturePhoto() {
                        capturedImages.append(image)
                    }
                }
            } label: {
                Circle()
                    .stroke(Color.gray, lineWidth: 4)
                    .frame(width: 70, height: 70)
                    .overlay {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                    }
            }

            // フォトライブラリボタン
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: maxPhotos - photos.count - capturedImages.count,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
            }
            .onChange(of: selectedItems) { _, newItems in
                loadSelectedPhotos(from: newItems)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }

    // MARK: - Helper Methods

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        capturedImages.append(uiImage)
                    }
                }
            }
            await MainActor.run {
                selectedItems.removeAll()
            }
        }
    }

    private func savePhotos() {
        for image in capturedImages {
            if let data = image.jpegData(compressionQuality: compressionQuality) {
                photos.append(data)
            }
        }
        // 認識された日付を保存
        if let date = cameraManager.detectedDate {
            recognizedDate = date
            onDateRecognized?(date)
        }
        // 認識された商品名を保存
        if let name = cameraManager.selectedProductName {
            onProductNameRecognized?(name)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Camera Preview View (Minimal UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateFrame()
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }

    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        return layer
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func updateFrame() {
        previewLayer.frame = bounds
    }
}

#Preview {
    PhotoCaptureSheet(photos: .constant([]), recognizedDate: .constant(nil))
}
