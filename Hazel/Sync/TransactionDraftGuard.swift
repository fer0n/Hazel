//
//  TransactionDraftGuard.swift
//  Hazel
//
//  Safety net behind the wallet automations' "Ensure Completion" parameter.
//  begin() marks a transaction/expense as started and schedules a local
//  notification a short delay out; complete() cancels that notification and
//  clears the draft once the transaction actually finishes (created,
//  queued, or a deliberate "don't split").
//
//  There's no way to resume a suspended App Intent perform() call — if a
//  follow-up question gets dismissed or the process is killed outright
//  (screen locked, a Shortcuts prompt timing out), that execution is simply
//  gone, with no state left to pick back up from. This only guarantees the
//  user gets *notified* it didn't finish: the notification is registered
//  with the OS up front and only cancelled by a successful completion, so
//  it fires on its own even with zero chance to run cleanup code.
//

import Foundation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.pentlandFirth.Hazel", category: "TransactionDraftGuard")

nonisolated enum TransactionDraftGuard {
    /// Long enough that a normal, uninterrupted run always finishes and
    /// cancels this first; short enough to still be a timely nudge if
    /// something goes wrong.
    private static let fireDelay: TimeInterval = 20

    @discardableResult
    static func begin(summary: String, service: TransactionDraft.Service) -> UUID {
        let draft = TransactionDraft(id: UUID(), startedAt: Date(), summary: summary, service: service)
        var drafts = TransactionDraftStore.load()
        drafts.append(draft)
        do {
            try TransactionDraftStore.save(drafts)
        } catch {
            logger.error("failed to save transaction draft: \(String(describing: error), privacy: .public)")
        }
        scheduleNotification(for: draft)
        return draft.id
    }

    static func complete(_ id: UUID) {
        var drafts = TransactionDraftStore.load()
        drafts.removeAll { $0.id == id }
        do {
            try TransactionDraftStore.save(drafts)
        } catch {
            logger.error("failed to save transaction drafts: \(String(describing: error), privacy: .public)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    private static func scheduleNotification(for draft: TransactionDraft) {
        let content = UNMutableNotificationContent()
        content.title = "Continue Adding Transaction"
        content.body = "\(draft.summary) — still needs to be added to \(draft.service.displayName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDelay, repeats: false)
        let request = UNNotificationRequest(identifier: draft.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("failed to schedule draft notification: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
