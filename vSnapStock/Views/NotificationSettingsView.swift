//
//  NotificationSettingsView.swift
//  vSnapStock
//
//  Created by Claude on 2026/01/03.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var colorManager = ColorSettingsManager.shared

    // UserDefaultsと連携する設定値
    @AppStorage("Notification_Enabled") private var isEnabled = true
    @AppStorage("Notification_NotifyOnDay") private var notifyOnDay = true
    @AppStorage("Notification_NotifyInAdvance") private var notifyInAdvance = true
    @AppStorage("Notification_AdvanceDays") private var advanceDays = 3
    @AppStorage("Notification_Hour") private var notificationHour = 9
    @AppStorage("Notification_Minute") private var notificationMinute = 0

    // DatePicker用のバインディング
    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationHour = components.hour ?? 9
                notificationMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "notification.enable_notifications"), isOn: $isEnabled)
                }

                if isEnabled {
                    Section(String(localized: "notification.timing")) {
                        Toggle(String(localized: "notification.on_expiration_day"), isOn: $notifyOnDay)
                        
                        Toggle(String(localized: "notification.in_advance"), isOn: $notifyInAdvance)
                        
                        if notifyInAdvance {
                            Stepper(
                                String(localized: "notification.days_before_count \(advanceDays)"),
                                value: $advanceDays,
                                in: 1...30
                            )
                        }
                    }

                    Section(String(localized: "notification.time")) {
                        DatePicker(
                            String(localized: "notification.time_label"),
                            selection: notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
                
                Section {
                    Text(String(localized: "notification.note"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            .navigationTitle(String(localized: "menu.notification_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(colorManager.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NotificationSettingsView()
}