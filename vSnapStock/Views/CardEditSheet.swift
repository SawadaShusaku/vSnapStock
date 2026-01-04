//
//  CardEditSheet.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import SwiftData
import PhotosUI

struct CardEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let card: Card?
    let folder: Folder?

    @State private var title: String = ""
    @State private var cardDescription: String = ""
    @State private var photos: [Data] = []
    @State private var expirationDate: Date?
    @State private var useByDate: Date?
    @State private var showDatePicker = false
    @State private var showPhotoSheet = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var expirationType: ExpirationType = .bestBefore
    @State private var colorManager = ColorSettingsManager.shared
    @State private var isInitialCameraMode: Bool

    enum ExpirationType: CaseIterable {
        case bestBefore
        case useBy

        var localizedName: String {
            switch self {
            case .bestBefore:
                return String(localized: "date.best_before")
            case .useBy:
                return String(localized: "date.use_by")
            }
        }
    }

    private var isNewCard: Bool { card == nil }
    private let maxPhotos = 10
    private let maxTitleLength = 40
    private let maxDescriptionLength = 1000

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    init(card: Card?, folder: Folder?) {
        self.card = card
        self.folder = folder
        // 新規作成時は最初にカメラを表示するモードで開始
        _isInitialCameraMode = State(initialValue: card == nil)
    }

    var body: some View {
        if isInitialCameraMode {
            // 新規作成時の初期カメラ表示（シートを重ねずに表示）
            PhotoCaptureSheet(
                photos: $photos,
                onDateRecognized: { date in
                    setCurrentDate(date)
                },
                onProductNameRecognized: { name in
                    title = String(name.prefix(maxTitleLength))
                },
                onDescriptionRecognized: { desc in
                    cardDescription = String(desc.prefix(maxDescriptionLength))
                },
                onCancel: {
                    dismiss()
                },
                onDone: {
                    isInitialCameraMode = false
                }
            )
        } else {
            formView
        }
    }

    var formView: some View {
        NavigationStack {
            Form {
                // 写真セクション
                photoSection

                // 基本情報セクション
                basicInfoSection

                // 期限セクション
                expirationSection
            }
            .scrollContentBackground(.hidden)
            .background(
                Group {
                    if let gradient = colorManager.backgroundGradient {
                        gradient
                    } else {
                        colorManager.backgroundColor
                    }
                }
                .ignoresSafeArea()
            )
            .navigationTitle(isNewCard ? String(localized: "card.new_title") : String(localized: "card.edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.save")) {
                        saveCard()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCardData()
            }
            .sheet(isPresented: $showPhotoSheet) {
                PhotoCaptureSheet(
                    photos: $photos,
                    onDateRecognized: { date in
                        setCurrentDate(date)
                    },
                    onProductNameRecognized: { name in
                        // 商品名をタイトルに設定（常に上書き）
                        title = String(name.prefix(maxTitleLength))
                    },
                    onDescriptionRecognized: { desc in
                        // 説明を追加（既存の説明がある場合は改行して追加）
                        if cardDescription.isEmpty {
                            cardDescription = String(desc.prefix(maxDescriptionLength))
                        } else {
                            let newDesc = cardDescription + "\n" + desc
                            cardDescription = String(newDesc.prefix(maxDescriptionLength))
                        }
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 既存の写真
                    ForEach(photos.indices, id: \.self) { index in
                        if let uiImage = UIImage(data: photos[index]) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }

                    // 追加ボタン
                    if photos.count < maxPhotos {
                        Button {
                            showPhotoSheet = true
                        } label: {
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text(String(localized: "button.add"))
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text(String(localized: "photo.count", defaultValue: "Photos (\(photos.count)/10)"))
        }
    }

    private var basicInfoSection: some View {
        Section {
            TextField(String(localized: "card.title_placeholder", defaultValue: "タイトル"), text: $title)
                .onChange(of: title) { _, newValue in
                    if newValue.count > maxTitleLength {
                        title = String(newValue.prefix(maxTitleLength))
                    }
                }

            ZStack(alignment: .topLeading) {
                if cardDescription.isEmpty {
                    Text(String(localized: "placeholder.enter_description"))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $cardDescription)
                    .frame(minHeight: 100)
                    .onChange(of: cardDescription) { _, newValue in
                        if newValue.count > maxDescriptionLength {
                            cardDescription = String(newValue.prefix(maxDescriptionLength))
                        }
                    }
            }
        } header: {
            Text(String(localized: "card.basic_info"))
        } footer: {
            Text(String(localized: "description.char_count", defaultValue: "Description: \(cardDescription.count)/\(maxDescriptionLength) chars"))
        }
    }

    private var expirationSection: some View {
        Section(String(localized: "card.expiration")) {
            // 期限タイプ選択
            HStack {
                Menu {
                    ForEach(ExpirationType.allCases, id: \.self) { type in
                        Button {
                            switchExpirationType(to: type)
                        } label: {
                            HStack {
                                Text(type.localizedName)
                                if expirationType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(expirationType.localizedName)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let date = currentDate {
                    Text(dateFormatter.string(from: date))
                        .foregroundColor(.secondary)
                    Button {
                        clearCurrentDate()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(String(localized: "date.not_set"))
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showDatePicker.toggle()
            }

            if showDatePicker {
                DatePicker(
                    expirationType.localizedName,
                    selection: Binding(
                        get: { currentDate ?? Date() },
                        set: { setCurrentDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale.current)
            }
        }
    }

    private var currentDate: Date? {
        switch expirationType {
        case .bestBefore:
            return expirationDate
        case .useBy:
            return useByDate
        }
    }

    private func setCurrentDate(_ date: Date) {
        switch expirationType {
        case .bestBefore:
            expirationDate = date
        case .useBy:
            useByDate = date
        }
    }

    private func clearCurrentDate() {
        switch expirationType {
        case .bestBefore:
            expirationDate = nil
        case .useBy:
            useByDate = nil
        }
    }

    private func switchExpirationType(to newType: ExpirationType) {
        // 現在の日付を新しいタイプに移動
        if let date = currentDate {
            clearCurrentDate()
            expirationType = newType
            setCurrentDate(date)
        } else {
            expirationType = newType
        }
    }

    // MARK: - Functions

    private func loadCardData() {
        guard let card = card else { return }
        title = card.title
        cardDescription = card.cardDescription
        photos = card.photos
        expirationDate = card.expirationDate
        useByDate = card.useByDate

        // 既存カードの期限タイプを判定
        if card.useByDate != nil {
            expirationType = .useBy
        } else {
            expirationType = .bestBefore
        }
    }

    private func saveCard() {
        if let card = card {
            // 既存カードの更新
            card.title = title
            card.cardDescription = cardDescription
            card.photos = photos
            card.expirationDate = expirationDate
            card.useByDate = useByDate
            card.touch()
            NotificationManager.shared.scheduleNotification(for: card)
        } else {
            // 既存カードのsortOrderを1ずつ増やす
            let descriptor = FetchDescriptor<Card>(
                predicate: #Predicate { !$0.isArchived && !$0.isDeleted }
            )
            if let existingCards = try? modelContext.fetch(descriptor) {
                for existingCard in existingCards {
                    existingCard.sortOrder += 1
                }
            }

            // 新規カード作成（先頭に追加）
            let newCard = Card(
                title: title,
                cardDescription: cardDescription,
                photos: photos,
                expirationDate: expirationDate,
                useByDate: useByDate,
                sortOrder: 0,
                folder: folder
            )
            modelContext.insert(newCard)
            NotificationManager.shared.scheduleNotification(for: newCard)
        }
    }
}

#Preview {
    CardEditSheet(card: nil, folder: nil)
        .modelContainer(for: Card.self, inMemory: true)
}
