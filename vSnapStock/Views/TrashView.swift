//
//  TrashView.swift
//  vSnapStock
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<Card> { card in
            card.isDeleted == true
        },
        sort: \Card.deletedAt,
        order: .reverse
    ) private var deletedCards: [Card]

    @State private var showEmptyConfirmation = false
    @State private var colorManager = ColorSettingsManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if deletedCards.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(deletedCards) { card in
                            TrashCardItem(card: card, onDelete: {
                                deleteCard(card)
                            })
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
            .navigationTitle(String(localized: "trash.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.close")) {
                        dismiss()
                    }
                }
                if !deletedCards.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "button.delete_all")) {
                            showEmptyConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                String(localized: "trash.dialog_title"),
                isPresented: $showEmptyConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "button.delete_all"), role: .destructive) {
                    emptyTrash()
                }
                Button(String(localized: "button.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "trash.dialog_message"))
            }
            .onAppear {
                cleanupExpiredCards()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(String(localized: "trash.empty"))
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func deleteCard(_ card: Card) {
        modelContext.delete(card)
    }

    private func emptyTrash() {
        for card in deletedCards {
            modelContext.delete(card)
        }
    }

    private func cleanupExpiredCards() {
        for card in deletedCards where card.shouldBeDeleted {
            modelContext.delete(card)
        }
    }
}

// MARK: - Trash Card Item
struct TrashCardItem: View {
    let card: Card
    let onDelete: () -> Void
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
                    .opacity(0.7)
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

                if let deletedAt = card.deletedAt {
                    Text(daysRemaining(from: deletedAt))
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(colorManager.cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button {
                card.restore()
            } label: {
                Label(String(localized: "button.restore"), systemImage: "arrow.uturn.backward")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "button.permanently_delete"), systemImage: "trash.fill")
            }
        }
    }

    private func daysRemaining(from deletedAt: Date) -> String {
        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: 7, to: deletedAt)!
        let daysLeft = calendar.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0

        if daysLeft <= 0 {
            return String(localized: "trash.delete_soon")
        } else if daysLeft == 1 {
            return String(localized: "trash.delete_in_1_day")
        } else {
            return String(localized: "trash.delete_in_days", defaultValue: "Delete in \(daysLeft) days")
        }
    }
}

#Preview {
    TrashView()
        .modelContainer(for: Card.self, inMemory: true)
}
