//
//  NotificationManager.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import UserNotifications
import UIKit

class NotificationManager {
    static let shared = NotificationManager()

    // 設定キー
    private let kEnabled = "Notification_Enabled"
    private let kNotifyOnDay = "Notification_NotifyOnDay"
    private let kNotifyInAdvance = "Notification_NotifyInAdvance"
    private let kAdvanceDays = "Notification_AdvanceDays"
    private let kNotificationHour = "Notification_Hour"
    private let kNotificationMinute = "Notification_Minute"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    // 設定値の取得
    var isEnabled: Bool { UserDefaults.standard.object(forKey: kEnabled) as? Bool ?? true }
    var notifyOnDay: Bool { UserDefaults.standard.object(forKey: kNotifyOnDay) as? Bool ?? true }
    var notifyInAdvance: Bool { UserDefaults.standard.object(forKey: kNotifyInAdvance) as? Bool ?? true }
    var advanceDays: Int { UserDefaults.standard.object(forKey: kAdvanceDays) as? Int ?? 3 }
    var notificationHour: Int { UserDefaults.standard.object(forKey: kNotificationHour) as? Int ?? 9 }
    var notificationMinute: Int { UserDefaults.standard.object(forKey: kNotificationMinute) as? Int ?? 0 }

    func scheduleNotification(for card: Card) {
        // まず既存の通知をキャンセル
        cancelNotification(for: card)

        // ゴミ箱に入っている、またはアーカイブされている場合は通知しない
        if card.isDeleted || card.isArchived { return }
        
        // 通知自体が無効なら終了
        guard isEnabled else { return }

        guard let date = card.useByDate ?? card.expirationDate else { return }
        let title = card.title.isEmpty ? String(localized: "card.untitled") : card.title

        // 1. 当日通知
        if notifyOnDay {
            schedule(id: card.id.uuidString + "_today",
                     title: String(localized: "notification.expired_today_title"),
                     body: String(localized: "notification.expired_today_body \(title)"),
                     date: date,
                     daysBefore: 0)
        }

        // 2. 事前通知
        if notifyInAdvance {
            schedule(id: card.id.uuidString + "_advance",
                     title: String(localized: "notification.expiring_soon_title"),
                     body: String(localized: "notification.expiring_soon_body \(title) \(advanceDays)"),
                     date: date,
                     daysBefore: advanceDays)
        }
    }

    private func schedule(id: String, title: String, body: String, date: Date, daysBefore: Int) {
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: -daysBefore, to: date) else { return }

        // 過去の日付ならスケジュールしない
        if targetDate < Date() { return }

        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = notificationHour
        components.minute = notificationMinute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for card: Card) {
        // _3daysは旧仕様のID、_advanceは新仕様
        let ids = [card.id.uuidString + "_today", card.id.uuidString + "_3days", card.id.uuidString + "_advance"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}