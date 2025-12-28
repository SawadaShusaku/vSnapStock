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

    @State private var title: String = ""
    @State private var cardDescription: String = ""
    @State private var photos: [Data] = []
    @State private var expirationDate: Date?
    @State private var useByDate: Date?
    @State private var showDatePicker = false
    @State private var showPhotoSheet = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var expirationType: ExpirationType = .bestBefore

    enum ExpirationType: String, CaseIterable {
        case bestBefore = "賞味期限"
        case useBy = "消費期限"
    }

    private var isNewCard: Bool { card == nil }
    private let maxPhotos = 10
    private let maxTitleLength = 40
    private let maxDescriptionLength = 1000

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }

    var body: some View {
        NavigationStack {
            Form {
                // 写真セクション
                photoSection

                // 基本情報セクション
                basicInfoSection

                // 期限セクション
                expirationSection
            }
            .navigationTitle(isNewCard ? "新規カード" : "カード編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCard()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCardData()
                // 新規カードの場合、自動でカメラシートを開く
                if isNewCard {
                    showPhotoSheet = true
                }
            }
            .sheet(isPresented: $showPhotoSheet) {
                PhotoCaptureSheet(
                    photos: $photos,
                    onDateRecognized: { date in
                        setCurrentDate(date)
                    },
                    onProductNameRecognized: { name in
                        // 商品名をタイトルに設定（空の場合のみ）
                        if title.isEmpty {
                            title = String(name.prefix(maxTitleLength))
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
                                Text("追加")
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
            Text("写真（\(photos.count)/\(maxPhotos)）")
        }
    }

    private var basicInfoSection: some View {
        Section {
            TextField("タイトル", text: $title)
                .onChange(of: title) { _, newValue in
                    if newValue.count > maxTitleLength {
                        title = String(newValue.prefix(maxTitleLength))
                    }
                }

            ZStack(alignment: .topLeading) {
                if cardDescription.isEmpty {
                    Text("説明を入力...")
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
            Text("基本情報")
        } footer: {
            Text("説明: \(cardDescription.count)/\(maxDescriptionLength)文字")
        }
    }

    private var expirationSection: some View {
        Section("期限") {
            // 期限タイプ選択
            HStack {
                Menu {
                    ForEach(ExpirationType.allCases, id: \.self) { type in
                        Button {
                            switchExpirationType(to: type)
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                if expirationType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(expirationType.rawValue)
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
                    Text("未設定")
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showDatePicker.toggle()
            }

            if showDatePicker {
                DatePicker(
                    expirationType.rawValue,
                    selection: Binding(
                        get: { currentDate ?? Date() },
                        set: { setCurrentDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ja_JP"))
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
                sortOrder: 0
            )
            modelContext.insert(newCard)
        }
    }
}

#Preview {
    CardEditSheet(card: nil)
        .modelContainer(for: Card.self, inMemory: true)
}
