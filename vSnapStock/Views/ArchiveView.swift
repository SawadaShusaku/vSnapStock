//
//  ArchiveView.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Card> { card in
            card.isArchived == true && card.isDeleted == false
        },
        sort: \Card.updatedAt,
        order: .reverse
    ) private var archivedCards: [Card]

    @State private var selectedCard: Card?
    @State private var colorManager = ColorSettingsManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if archivedCards.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(archivedCards) { card in
                            ArchiveCardItem(card: card)
                                .onTapGesture {
                                    selectedCard = card
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
            .navigationTitle(String(localized: "archive.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedCard) { card in
                CardEditSheet(card: card)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(String(localized: "archive.empty"))
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Archive Card Item
struct ArchiveCardItem: View {
    let card: Card
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
                Text(card.title.isEmpty ? String(localized: "card.untitled") : card.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(colorManager.cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button {
                card.unarchive()
            } label: {
                Label(String(localized: "button.return_home"), systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button(role: .destructive) {
                card.moveToTrash()
            } label: {
                Label(String(localized: "button.delete"), systemImage: "trash")
            }
        }
    }
}

#Preview {
    ArchiveView()
        .modelContainer(for: Card.self, inMemory: true)
}
