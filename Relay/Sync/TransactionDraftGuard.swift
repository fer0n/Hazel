//
//  TransactionDraftGuard.swift
//  Relay
//
//  Safety net behind the wallet automations' "Ensure Completion" parameter.
//  begin() marks a transaction/expense as started and schedules a local
//  notification a short delay out; touch() pushes that deadline back out
//  again (called after every follow-up question is answered, so a normal
//  but slow-to-answer run — typing a new template name, picking a category —
//  doesn't get a premature nudge while the user is still actively working
//  through it); fail() fires the notification right away instead of
//  waiting out that window, for the case where perform() is still alive to
//  catch its own error (a real API/validation failure) and already knows
//  for certain the run won't finish; complete() cancels the notification
//  and clears the draft once the transaction actually finishes (created,
//  queued, or a deliberate "don't split").
//
//  There's no way to resume a suspended App Intent perform() call — if a
//  follow-up question gets dismissed or the process is killed outright
//  (screen locked, a Shortcuts prompt timing out), that execution is simply
//  gone, with no state left to pick back up from. This only guarantees the
//  user gets *notified* it didn't finish: the notification is registered
//  with the OS up front and only cancelled by a successful completion, so
//  it fires on its own even with zero chance to run cleanup code. Tapping it
//  opens Relay to ContinueYNABWalletTransactionView/
//  ContinueSplitwiseWalletTransactionView (see DraftNotificationRouter) to
//  actually finish the transaction from scratch, using the raw inputs saved
//  in `payload`.
//

import Foundation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.octabits.relay", category: "TransactionDraftGuard")

enum TransactionDraftGuard {
    /// How long a run can go quiet (no question answered, no completion)
    /// before the reminder fires. touch() resets this on every answered
    /// question, so it's really "30s of inactivity", not "30s since the
    /// run started".
    private static let fireDelay: TimeInterval = 30

    @discardableResult
    static func begin(_ payload: TransactionDraft.Payload) -> UUID {
        let draft = TransactionDraft(id: UUID(), startedAt: Date(), payload: payload)
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

    /// Pushes the reminder deadline back out to `fireDelay` from now —
    /// call after every follow-up question is answered. Re-adding a
    /// notification request with the same identifier replaces the pending
    /// one outright, and this also clears an already-*delivered* copy (the
    /// user could easily answer a later question after the first one took
    /// long enough for the original reminder to already have fired), so
    /// there's never a stale reminder sitting around once the run is
    /// visibly still making progress.
    ///
    /// Whether the rescheduled reminder carries the split actions follows
    /// the draft's `pendingSplitContext`: it's set only while the split
    /// choice is the open question (armSplitChoice … disarmSplitChoice), so
    /// a touch before or after that window reschedules plain, and one during
    /// it keeps the actions.
    static func touch(_ id: UUID) {
        guard let draft = TransactionDraftStore.load().first(where: { $0.id == id }) else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id.uuidString])
        scheduleNotification(for: draft)
    }

    /// Called on the Splitwise-side draft right before perform() asks the
    /// live "split with Splitwise?" question — at which point the YNAB
    /// transaction is already committed and the split is the only thing left.
    /// Saves the expense description + resolved friend onto the draft and
    /// reschedules its reminder carrying the Split Equally / Manually / Don't
    /// Split actions, so an interruption *at this question* — the single most
    /// common one for a recurring merchant — can be answered straight from
    /// the notification (see WalletDraftCompletion). Also resets the
    /// quiet-period timer, since the user is now being actively prompted.
    static func armSplitChoice(_ id: UUID, context: TransactionDraft.PendingSplitContext) {
        var drafts = TransactionDraftStore.load()
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[index].pendingSplitContext = context
        do {
            try TransactionDraftStore.save(drafts)
        } catch {
            logger.error("failed to save split context on draft: \(String(describing: error), privacy: .public)")
        }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id.uuidString])
        scheduleNotification(for: drafts[index])
    }

    /// Clears the armed split context once the split choice has actually been
    /// answered — call right after the run gets past that question. From here
    /// on any interruption (or a fail()) reschedules a *plain* reminder,
    /// since the quick-reply actions only make sense while the split is still
    /// the open question. Rescheduling itself is left to the touch() that
    /// immediately follows.
    static func disarmSplitChoice(_ id: UUID) {
        var drafts = TransactionDraftStore.load()
        guard let index = drafts.firstIndex(where: { $0.id == id }),
              drafts[index].pendingSplitContext != nil else { return }
        drafts[index].pendingSplitContext = nil
        do {
            try TransactionDraftStore.save(drafts)
        } catch {
            logger.error("failed to clear split context on draft: \(String(describing: error), privacy: .public)")
        }
    }

    /// Re-delivers a *plain* draft reminder right away after a notification
    /// action couldn't finish the transaction on its own (no friend to split
    /// with, an unparseable manual share). The draft still exists, so tapping
    /// this opens ContinueDraftView to finish it by hand — and it deliberately
    /// drops the split actions so the user isn't offered a quick reply that
    /// already failed once.
    static func notifyNeedsApp(_ id: UUID) {
        guard let draft = TransactionDraftStore.load().first(where: { $0.id == id }) else { return }
        scheduleNotification(
            for: draft,
            delay: 1,
            body: "\(draft.summary). Couldn't finish automatically — tap to complete in Relay.",
            splitActions: false
        )
    }

    /// Fires the reminder right away — call when perform() is about to
    /// throw. A real error (or a dismissed follow-up question that unwinds
    /// perform() while it's still alive to run this) means the run has
    /// already definitively ended without creating/queuing anything, so
    /// there's no reason to make the user wait out the usual quiet-period
    /// window before finding out. Keeps the split actions when the throw
    /// happened *at* the split question (context still armed) — dismissing
    /// that prompt is exactly the case the quick reply is for.
    static func fail(_ id: UUID) {
        guard let draft = TransactionDraftStore.load().first(where: { $0.id == id }) else { return }
        scheduleNotification(for: draft, delay: 1)
    }

    static func complete(_ id: UUID) {
        var drafts = TransactionDraftStore.load()
        drafts.removeAll { $0.id == id }
        do {
            try TransactionDraftStore.save(drafts)
        } catch {
            logger.error("failed to save transaction drafts: \(String(describing: error), privacy: .public)")
        }
        // Covers both cases: the notification hasn't fired yet (e.g. a fast
        // run), or it already has (e.g. the user was mid-checkout and only
        // just got back to answering a follow-up question) — either way,
        // once the transaction's actually done it shouldn't linger.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [id.uuidString])
    }

    /// `splitActions` overrides whether the reminder carries the split
    /// quick-reply actions; when nil (the default) it follows the draft's
    /// armed `pendingSplitContext`, so every scheduling path — begin, touch,
    /// and especially fail (the "caught" path) — keeps the actions while the
    /// split is the open question and drops them otherwise. notifyNeedsApp
    /// passes `false` to force a plain reminder even though the context is
    /// still set.
    private static func scheduleNotification(
        for draft: TransactionDraft,
        delay: TimeInterval = fireDelay,
        body: String? = nil,
        splitActions: Bool? = nil
    ) {
        guard NotificationsPreferenceStore.isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if splitActions ?? (draft.pendingSplitContext != nil) {
            // The split-choice reminder: the transaction (YNAB) is already
            // done, so this isn't "incomplete" — it just offers the optional
            // split. Title carries the summary, body poses the question the
            // Split Equally / Manually / Don't Split actions answer.
            content.categoryIdentifier = WalletSplitNotification.categoryIdentifier
            content.title = draft.summary
            if let friendName = draft.pendingSplitContext?.friend?.firstName {
                content.body = "Split with \(friendName)?"
            } else {
                content.body = "Split this expense?"
            }
        } else {
            content.title = "Transaction Incomplete"
            content.body = body ?? "\(draft.summary). Tap to continue."
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: draft.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("failed to schedule draft notification: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
