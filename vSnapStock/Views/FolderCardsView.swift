//
//  FolderCardsView.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import SwiftUI
import SwiftData

struct FolderCardsView: View {
    @Environment(\.modelContext) private var modelContext
    let folder: Folder
    @Query private var queriedCards: [Card]

    @State private var showingAddSheet = false
    @State private var selectedCard: Card?
    @State private var sortOption: SortOption = .expirationDateAsc
    @State private var draggingCard: Card?
    @State private var showingArchive = false
    @State private var showingTrash = false
    @State private var showingColorSettings = false
    @State private var showingOCRSettings = false
    @State private var showingNotificationSettings = false
    @State private var colorManager = ColorSettingsManager.shared

    init(folder: Folder) {
        self.folder = folder
        let folderId = folder.id
        let predicate = #Predicate<Card> { card in
            card.folder?.id == folderId &&
            card.isArchived == false &&
            card.isDeleted == false
        }
        _queriedCards = Query(filter: predicate)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    enum SortOption: String, CaseIterable {
        case expirationDateAsc
        case expirationDateDesc
        case titleAsc
        case custom

        var localizedName: String {
            switch self {
            case .expirationDateAsc: return String(localized: "sort.expiration_asc")
            case .expirationDateDesc: return String(localized: "sort.expiration_desc")
            case .titleAsc: return String(localized: "sort.title_asc")
            case .custom: return String(localized: "sort.custom")
            }
        }

        var systemImage: String {
            switch self {
            case .expirationDateAsc: return "hourglass.bottomhalf.filled"
            case .expirationDateDesc: return "hourglass.tophalf.filled"
            case .titleAsc: return "textformat"
            case .custom: return "list.bullet"
            }
        }
    }

    // フォルダのカードをフィルタリング
    private var cards: [Card] {
        let filtered = queriedCards

        switch sortOption {
        case .expirationDateAsc:
            return filtered.sorted {
                let date1 = $0.useByDate ?? $0.expirationDate ?? Date.distantFuture
                let date2 = $1.useByDate ?? $1.expirationDate ?? Date.distantFuture
                if date1 == date2 { return $0.sortOrder < $1.sortOrder }
                return date1 < date2
            }
        case .expirationDateDesc:
            return filtered.sorted {
                let date1 = $0.useByDate ?? $0.expirationDate ?? Date.distantPast
                let date2 = $1.useByDate ?? $1.expirationDate ?? Date.distantPast
                if date1 == date2 { return $0.sortOrder < $1.sortOrder }
                return date1 > date2
            }
        case .titleAsc:
            return filtered.sorted { $0.title < $1.title }
        case .custom:
            return filtered.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                if cards.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(cards) { card in
                            if sortOption == .custom {
                                CardGridItem(card: card)
                                    .onTapGesture {
                                        selectedCard = card
                                    }
                                    .draggable(card.id.uuidString) {
                                        CardGridItem(card: card)
                                            .frame(width: 150)
                                            .opacity(0.8)
                                            .onAppear {
                                                draggingCard = card
                                            }
                                    }
                                    .dropDestination(for: String.self) { items, _ in
                                        guard let droppedId = items.first,
                                              let sourceCard = draggingCard,
                                              sourceCard.id.uuidString == droppedId,
                                              sourceCard.id != card.id else {
                                            return false
                                        }
                                        reorderCards(from: sourceCard, to: card)
                                        return true
                                    } isTargeted: { _ in }
                            } else {
                                CardGridItem(card: card)
                                    .onTapGesture {
                                        selectedCard = card
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }
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

            addButton
        }
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
        // .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
        // .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    sortButton
                    menuButton
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            CardEditSheet(card: nil, folder: folder)
        }
        .sheet(item: $selectedCard) { card in
            CardEditSheet(card: card, folder: folder)
        }
        .sheet(isPresented: $showingArchive) {
            ArchiveView()
        }
        .sheet(isPresented: $showingTrash) {
            TrashView()
        }
        .sheet(isPresented: $showingColorSettings) {
            ColorSettingsView()
        }
        .sheet(isPresented: $showingOCRSettings) {
            OCRSettingsView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .onAppear {
            UserDefaults.standard.set(folder.id.uuidString, forKey: "LastOpenedFolderId")
            loadSortOption()
        }
        .onChange(of: sortOption) { _, newValue in
            saveSortOption(newValue)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(String(localized: "empty.no_cards"))
                .font(.headline)
                .foregroundColor(.gray)
            Text(String(localized: "empty.add_from_button"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding()
    }

    private var sortButton: some View {
        Menu {
            Picker(String(localized: "menu.sort"), selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Label(option.localizedName, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.title3)
        }
    }

    private var menuButton: some View {
        Menu {
            Button {
                showingArchive = true
            } label: {
                Label(String(localized: "menu.archive"), systemImage: "archivebox")
            }

            Button {
                showingTrash = true
            } label: {
                Label(String(localized: "menu.trash"), systemImage: "trash")
            }

            Divider()

            Button {
                showingColorSettings = true
            } label: {
                Label(String(localized: "menu.color"), systemImage: "paintpalette")
            }

            Button {
                showingOCRSettings = true
            } label: {
                Label(String(localized: "menu.ocr_settings"), systemImage: "text.viewfinder")
            }

            Button {
                showingNotificationSettings = true
            } label: {
                Label(String(localized: "menu.notification_settings"), systemImage: "bell")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
    }

    private func reorderCards(from source: Card, to destination: Card) {
        guard let sourceIndex = cards.firstIndex(where: { $0.id == source.id }),
              let destIndex = cards.firstIndex(where: { $0.id == destination.id }) else {
            return
        }

        withAnimation {
            var reorderedCards = Array(cards)
            let movedCard = reorderedCards.remove(at: sourceIndex)
            reorderedCards.insert(movedCard, at: destIndex)

            for (index, card) in reorderedCards.enumerated() {
                card.sortOrder = index
            }
        }
    }

    private func sortOptionKey() -> String {
        "SortOption_\(folder.id.uuidString)"
    }

    private func loadSortOption() {
        if let savedSortRawValue = UserDefaults.standard.string(forKey: sortOptionKey()),
           let savedSortOption = SortOption(rawValue: savedSortRawValue) {
            sortOption = savedSortOption
        }
    }

    private func saveSortOption(_ option: SortOption) {
        UserDefaults.standard.set(option.rawValue, forKey: sortOptionKey())
    }
}

// MARK: - Card Grid Item
struct CardGridItem: View {
    let card: Card
    @Environment(\.modelContext) private var modelContext
    @State private var colorManager = ColorSettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 写真サムネイル
            if let firstPhotoData = card.photos.first,
               let uiImage = UIImage(data: firstPhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // タイトル
                Text(card.title.isEmpty ? String(localized: "card.untitled") : card.title)
                    .font(.headline)
                    .lineLimit(1)

                // 期限表示（賞味期限 or 消費期限）
                if let date = card.useByDate {
                    // 消費期限
                    Text(String(localized: "date.use_by_format \(formatDate(date))"))
                        .font(.caption)
                        .foregroundColor(expirationColor(for: date))
                } else if let date = card.expirationDate {
                    // 賞味期限
                    Text(String(localized: "date.best_before_format \(formatDate(date))"))
                        .font(.caption)
                        .foregroundColor(expirationColor(for: date))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(colorManager.cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button {
                card.archive()
                NotificationManager.shared.cancelNotification(for: card)
            } label: {
                Label(String(localized: "menu.archive"), systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                card.moveToTrash()
                NotificationManager.shared.cancelNotification(for: card)
                try? modelContext.save()
            } label: {
                Label(String(localized: "button.delete"), systemImage: "trash")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func expirationColor(for date: Date) -> Color {
        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysUntilExpiration < 0 {
            return .red
        } else if daysUntilExpiration <= 3 {
            return .orange
        } else {
            return .secondary
        }
    }
}
