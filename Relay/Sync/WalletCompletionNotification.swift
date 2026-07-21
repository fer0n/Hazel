//
//  WalletCompletionNotification.swift
//  Relay
//
//  Shared "success" confirmation banner for wallet automations and
//  notification quick-reply completions.
//

import Foundation
import UserNotifications
import os

private let walletCompletionLogger = Logger(subsystem: "com.octabits.relay", category: "WalletCompletionNotification")

enum WalletCompletionNotification {
    static func postConfirmation(title: String = String(localized: "Split Added"), dialog: String) {
        guard NotificationsPreferenceStore.isEnabled else { return }
        walletCompletionLogger.log("posting split confirmation")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = dialog

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                walletCompletionLogger.error("failed to post completion confirmation: \(String(describing: error), privacy: .public)")
            }
        }
    }
}