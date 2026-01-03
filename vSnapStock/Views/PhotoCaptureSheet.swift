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
    var onDescriptionRecognized: ((String) -> Void)?

    @State private var cameraManager = CameraManager()
    @State private var capturedImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingTextEditor = false
    @State private var editingText = ""
    @State private var editingTextType: TextScanType = .productName

    /// テキスト読取の種類
    enum TextScanType {
        case productName
        case description
    }

    private let compressionQuality: CGFloat = 0.7
    private let maxPhotos = 10

    /// 写真、日付、商品名、説明のいずれかがあれば完了可能
    private var hasAnyContent: Bool {
        !capturedImages.isEmpty ||
        cameraManager.detectedDate != nil ||
        cameraManager.selectedProductName != nil ||
        cameraManager.selectedDescription != nil
    }

    init(
        photos: Binding<[Data]>,
        recognizedDate: Binding<Date?> = .constant(nil),
        onDateRecognized: ((Date) -> Void)? = nil,
        onProductNameRecognized: ((String) -> Void)? = nil,
        onDescriptionRecognized: ((String) -> Void)? = nil
    ) {
        self._photos = photos
        self._recognizedDate = recognizedDate
        self.onDateRecognized = onDateRecognized
        self.onProductNameRecognized = onProductNameRecognized
        self.onDescriptionRecognized = onDescriptionRecognized
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
            .navigationTitle(String(localized: "photo.add_photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) {
                        savePhotos()
                        dismiss()
                    }
                    .disabled(!hasAnyContent)
                }
            }
            .task {
                await cameraManager.startSession()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .sheet(isPresented: $showingTextEditor) {
                TextEditorSheet(
                    text: $editingText,
                    title: editingTextType == .productName ? String(localized: "photo.edit_product_name") : String(localized: "photo.edit_description"),
                    placeholder: editingTextType == .productName ? String(localized: "photo.enter_product_name") : String(localized: "photo.enter_description"),
                    onSave: {
                        switch editingTextType {
                        case .productName:
                            cameraManager.selectedProductName = editingText
                        case .description:
                            cameraManager.selectedDescription = editingText
                        }
                    }
                )
                .presentationDetents([.height(200)])
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
                    Text(String(localized: "photo.camera_starting"))
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
                        if !item.isDate {
                            if cameraManager.isProductNameScanEnabled && cameraManager.selectedProductName == nil {
                                cameraManager.selectProductName(item)
                            } else if cameraManager.isDescriptionScanEnabled && cameraManager.selectedDescription == nil {
                                cameraManager.selectDescription(item)
                            }
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
        cameraManager.selectedProductName == item.text ||
        cameraManager.selectedDescription == item.text
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
                    Text(String(localized: "photo.captured_photos_appear_here"))
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
                    Text(String(localized: "photo.read_expiration_date"))
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

            // 商品名読取（プルダウンで説明を読取も選択可能）
            HStack {
                Menu {
                    Button {
                        selectTextScanMode(.productName)
                    } label: {
                        HStack {
                            Text(String(localized: "photo.read_product_name"))
                            if currentTextScanMode == .productName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        selectTextScanMode(.description)
                    } label: {
                        HStack {
                            Text(String(localized: "photo.read_description"))
                            if currentTextScanMode == .description {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                        Text(currentTextScanMode == .productName ? String(localized: "photo.read_product_name") : String(localized: "photo.read_description"))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: isTextScanEnabled)
                    .toggleStyle(.switch)
            }
            .padding(.horizontal)

            if cameraManager.isProductNameScanEnabled {
                productNameStatusView
            } else if cameraManager.isDescriptionScanEnabled {
                descriptionStatusView
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Text Scan Mode

    @State private var textScanMode: TextScanType = .productName

    private var currentTextScanMode: TextScanType {
        textScanMode
    }

    private var isTextScanEnabled: Binding<Bool> {
        Binding(
            get: {
                switch textScanMode {
                case .productName:
                    return cameraManager.isProductNameScanEnabled
                case .description:
                    return cameraManager.isDescriptionScanEnabled
                }
            },
            set: { newValue in
                switch textScanMode {
                case .productName:
                    cameraManager.isProductNameScanEnabled = newValue
                    if !newValue {
                        cameraManager.resetProductNameDetection()
                    }
                case .description:
                    cameraManager.isDescriptionScanEnabled = newValue
                    if !newValue {
                        cameraManager.resetDescriptionDetection()
                    }
                }
            }
        )
    }

    private func selectTextScanMode(_ mode: TextScanType) {
        textScanMode = mode
        switch mode {
        case .productName:
            cameraManager.isDescriptionScanEnabled = false
            cameraManager.resetDescriptionDetection()
            cameraManager.isProductNameScanEnabled = true
        case .description:
            cameraManager.isProductNameScanEnabled = false
            cameraManager.resetProductNameDetection()
            cameraManager.isDescriptionScanEnabled = true
        }
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
                Text(String(localized: "photo.looking_for_date"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var productNameStatusView: some View {
        if let name = cameraManager.selectedProductName {
            HStack(spacing: 4) {
                // タップで編集シートを開く
                Button {
                    editingText = name
                    editingTextType = .productName
                    showingTextEditor = true
                } label: {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }

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
                Text(String(localized: "photo.tap_text_to_select"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var descriptionStatusView: some View {
        if let desc = cameraManager.selectedDescription {
            HStack(spacing: 4) {
                // タップで編集シートを開く
                Button {
                    editingText = desc
                    editingTextType = .description
                    showingTextEditor = true
                } label: {
                    Text(desc)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                }

                Button {
                    cameraManager.resetDescriptionDetection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        } else {
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(.purple)
                Text(String(localized: "photo.tap_text_to_select"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 20) {
            // 1. ズームボタン（左端）
            Button {
                cameraManager.toggleZoom()
            } label: {
                Text(cameraManager.currentZoomFactor < 1.5 ? "1x" : "2x")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(cameraManager.currentZoomFactor < 1.5 ? .gray : .yellow)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .stroke(cameraManager.currentZoomFactor < 1.5 ? Color.gray : Color.yellow, lineWidth: 1.5)
                    )
            }

            // 2. フォトライブラリボタン
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: maxPhotos - photos.count - capturedImages.count,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
            }
            .onChange(of: selectedItems) { _, newItems in
                loadSelectedPhotos(from: newItems)
            }

            // 3. シャッターボタン（中央）
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

            // 4. フラッシュボタン（撮影時のフラッシュ）
            Button {
                cameraManager.isFlashEnabled.toggle()
            } label: {
                Image(systemName: cameraManager.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundColor(cameraManager.isFlashEnabled ? .yellow : .gray)
                    .frame(width: 44, height: 44)
            }

            // 5. ライトボタン（常時点灯トーチ、右端）
            Button {
                cameraManager.toggleTorch()
            } label: {
                Image(systemName: cameraManager.isTorchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .foregroundColor(cameraManager.isTorchEnabled ? .yellow : .gray)
                    .frame(width: 44, height: 44)
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
        // 認識された説明を保存
        if let desc = cameraManager.selectedDescription {
            onDescriptionRecognized?(desc)
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

// MARK: - Text Editor Sheet

struct TextEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    var title: String
    var placeholder: String
    var onSave: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField(placeholder, text: $text)
                    .font(.title2)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        saveAndDismiss()
                    }

                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        saveAndDismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func saveAndDismiss() {
        onSave()
        dismiss()
    }
}

#Preview {
    PhotoCaptureSheet(photos: .constant([]), recognizedDate: .constant(nil))
}
