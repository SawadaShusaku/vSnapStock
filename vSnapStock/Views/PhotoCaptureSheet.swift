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

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var isFlashOn = false

    private let compressionQuality: CGFloat = 0.7
    private let maxPhotos = 10

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カメラプレビューエリア
                if showCamera {
                    CameraPreviewView(
                        isFlashOn: $isFlashOn,
                        onCapture: { image in
                            capturedImages.append(image)
                        }
                    )
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                        .overlay {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("カメラを起動中...")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .onAppear {
                            checkCameraPermission()
                        }
                }

                // 撮影済み写真サムネイル
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

                Spacer()

                // コントロールボタン
                HStack(spacing: 40) {
                    // フラッシュボタン
                    Button {
                        isFlashOn.toggle()
                    } label: {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(isFlashOn ? .yellow : .gray)
                            .frame(width: 50, height: 50)
                    }

                    // シャッターボタン
                    Button {
                        // カメラビューから撮影をトリガー
                        NotificationCenter.default.post(name: .capturePhoto, object: nil)
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
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    showCamera = granted
                }
            }
        default:
            showCamera = false
        }
    }

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
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var isFlashOn: Bool
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.isFlashOn = isFlashOn
    }
}

class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var isFlashOn = false
    var onCapture: ((UIImage) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturePhoto),
            name: .capturePhoto,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              captureSession?.canAddInput(input) == true else {
            return
        }

        captureSession?.addInput(input)

        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           captureSession?.canAddOutput(photoOutput) == true {
            captureSession?.addOutput(photoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        view.layer.addSublayer(previewLayer!)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    @objc func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image)
        }
    }
}

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

#Preview {
    PhotoCaptureSheet(photos: .constant([]))
}
