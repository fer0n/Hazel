//
//  DraftNotificationRouter.swift
//  Hazel
//
//  Bridges a tapped "Continue Adding Transaction" notification (see
//  TransactionDraftGuard) into SwiftUI navigation: the notification's
//  identifier is the draft's UUID, so the delegate callback just needs to
//  hand that id to ContentView, which reacts by pushing
//  ContinueYNABWalletTransactionView/ContinueSplitwiseWalletTransactionView.
//

import Foundation
import Observation
import UserNotifications
import os

private let logger = Logger(subsystem: "com.pentlandFirth.Hazel", category: "DraftNotificationRouter")

@MainActor
@Observable
final class DraftNotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DraftNotificationRouter()

    /// Set when the user taps a draft notification; ContentView observes
    /// this and clears it once it's acted on.
    var pendingDraftID: UUID?

    private override init() {
        super.init()
    }

    /// Must be called as early as possible (HazelApp.init()) — UNUserNotificationCenter
    /// only delivers a tap response to a delegate that's already set by the
    /// time the response arrives.
    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            if let id = UUID(uuidString: identifier) {
                DraftNotificationRouter.shared.pendingDraftID = id
            } else {
                logger.error("draft notification identifier wasn't a UUID: \(identifier, privacy: .public)")
            }
            completionHandler()
        }
    }

    /// Shows the notification even while Hazel is already in the
    /// foreground — otherwise a fired reminder would be silently dropped if
    /// the user happened to have the app open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
