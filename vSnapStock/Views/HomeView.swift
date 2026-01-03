//
//  HomeView.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Card> { card in
            card.isArchived == false && card.isDeleted == false
        },
        sort: \Card.sortOrder
    ) private var cards: [Card]

    @State private var showingAddSheet = false
    @State private var selectedCard: Card?
    @State private var showingArchive = false
    @State private var showingTrash = false
    @State private var showingSettings = false
    @State private var showingColorSettings = false
    @State private var showingOCRSettings = false
    @State private var draggingCard: Card?
    @State private var colorManager = ColorSettingsManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    if cards.isEmpty {
                        emptyStateView
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(cards) { card in
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
                                    } isTargeted: { isTargeted in
                                        // ドロップターゲット時のハイライト（オプション）
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
                )

                // 追加ボタン
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
            )
            .navigationTitle(String(localized: "app.name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorManager.hasBackgroundGradient ? .dark : nil, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menuButton
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CardEditSheet(card: nil)
            }
            .sheet(item: $selectedCard) { card in
                CardEditSheet(card: card)
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
                showingSettings = true
            } label: {
                Label(String(localized: "menu.settings"), systemImage: "gearshape")
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
            // 新しい順序を計算して各カードに割り当て
            var reorderedCards = Array(cards)
            let movedCard = reorderedCards.remove(at: sourceIndex)
            reorderedCards.insert(movedCard, at: destIndex)

            for (index, card) in reorderedCards.enumerated() {
                card.sortOrder = index
            }
        }
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
                    Text("\(String(localized: "date.use_by")): \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(expirationColor(for: date))
                } else if let date = card.expirationDate {
                    // 賞味期限
                    Text("\(String(localized: "date.best_before")): \(formatDate(date))")
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
            } label: {
                Label(String(localized: "menu.archive"), systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                card.moveToTrash()
            } label: {
                Label(String(localized: "button.delete"), systemImage: "trash")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
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

#Preview {
    HomeView()
        .modelContainer(for: Card.self, inMemory: true)
}
