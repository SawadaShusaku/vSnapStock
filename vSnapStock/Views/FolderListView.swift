//
//  FolderListView.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import SwiftUI
import SwiftData

struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @Binding var navigationPath: NavigationPath
    @State private var showingAddFolder = false
    @State private var folderToEdit: Folder?
    @State private var folderToDelete: Folder?
    @State private var colorManager = ColorSettingsManager.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView
            addButton
        }
        // .navigationTitle("app.name")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            FolderEditSheet(folder: nil)
        }
        .sheet(item: $folderToEdit) { folder in
            FolderEditSheet(folder: folder)
        }
        .alert(String(localized: "folder.delete_title"), isPresented: .constant(folderToDelete != nil), presenting: folderToDelete) { folder in
            Button(String(localized: "button.cancel"), role: .cancel) {
                folderToDelete = nil
            }
            Button(String(localized: "button.delete"), role: .destructive) {
                deleteFolder(folder)
                folderToDelete = nil
            }
        } message: { folder in
            Text(String(localized: "folder.delete_confirm_message \(folder.name)"))
        }
        .onAppear {
            UserDefaults.standard.removeObject(forKey: "LastOpenedFolderId")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if folders.isEmpty {
            emptyStateView
                .background(backgroundView)
        } else {
            List {
                ForEach(folders) { folder in
                    folderRow(folder)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(backgroundView)
        }
    }

    private func folderRow(_ folder: Folder) -> some View {
        FolderListItem(folder: folder)
            .onTapGesture {
                navigationPath.append(AppNavigationPath.folderDetail(folder))
            }
            .contextMenu {
                Button {
                    folderToEdit = folder
                } label: {
                    Label(String(localized: "menu.rename"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    folderToDelete = folder
                } label: {
                    Label(String(localized: "button.delete"), systemImage: "trash")
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    folderToDelete = folder
                } label: {
                    Label(String(localized: "button.delete"), systemImage: "trash")
                }

                Button {
                    folderToEdit = folder
                } label: {
                    Label(String(localized: "button.edit"), systemImage: "pencil")
                }
                .tint(.blue)
            }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(String(localized: "folder.empty_title"))
                .font(.headline)
                .foregroundColor(.gray)
            Text(String(localized: "folder.empty_message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var addButton: some View {
        Button {
            showingAddFolder = true
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

    private var backgroundView: some View {
        Group {
            if let gradient = colorManager.backgroundGradient {
                gradient
            } else {
                colorManager.backgroundColor
            }
        }
        .ignoresSafeArea()
    }

    private func deleteFolder(_ folder: Folder) {
        // フォルダ内のすべてのカードをゴミ箱に移動
        if let cards = folder.cards {
            for card in cards {
                card.moveToTrash()
                NotificationManager.shared.cancelNotification(for: card)
            }
        }

        // フォルダを削除
        modelContext.delete(folder)
    }
}

struct FolderListItem: View {
    let folder: Folder
    @State private var colorManager = ColorSettingsManager.shared

    private var cardCount: Int {
        folder.cards?.filter { !$0.isArchived && !$0.isDeleted }.count ?? 0
    }

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(String(localized: "folder.card_count \(cardCount)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(colorManager.cardColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
