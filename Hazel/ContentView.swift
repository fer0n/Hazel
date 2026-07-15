//
//  ContentView.swift
//  Hazel
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var ynabAuth = YNABAuthService()
    @State private var splitwiseAuth = SplitwiseAuthService()
    @State private var pendingQueue = PendingOperationQueue.shared
    @State private var draftRouter = DraftNotificationRouter.shared
    @State private var draftCount = TransactionDraftStore.load().count
    @State private var didDeleteWalletConfig = false
    @State private var path: [ContentRoute] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                Text("Hazel")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)

                AccountConnectionRow(
                    title: "YNAB",
                    isConnected: ynabAuth.isAuthenticated,
                    connect: ynabAuth.signIn,
                    disconnect: ynabAuth.signOut
                )

                AccountConnectionRow(
                    title: "Splitwise",
                    isConnected: splitwiseAuth.isAuthenticated,
                    connect: splitwiseAuth.signIn,
                    disconnect: splitwiseAuth.signOut
                )

                if splitwiseAuth.isAuthenticated {
                    DefaultSplitwiseFriendRow()
                }

                NavigationLink(value: ContentRoute.templates) {
                    HStack {
                        Text("Templates")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                NavigationLink(value: ContentRoute.howHazelWorks) {
                    HStack {
                        Text("How Hazel Works")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                NavigationLink(value: ContentRoute.pendingQueue) {
                    HStack {
                        Text("Pending Queue")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if !pendingQueue.operations.isEmpty {
                            Text("\(pendingQueue.operations.count)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                NavigationLink(value: ContentRoute.transactionDrafts) {
                    HStack {
                        Text("Transaction Drafts")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if draftCount > 0 {
                            Text("\(draftCount)")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Delete Wallet Transaction Config") {
                    try? WalletTransactionConfigStore.delete()
                    didDeleteWalletConfig = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
                if didDeleteWalletConfig {
                    Text("Deleted")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Required by YNAB's API Terms of Service (see CLAUDE.md) —
                // must be visible somewhere in the app, not just the privacy
                // policy.
                Text("We are not affiliated, associated, or in any way officially connected with YNAB or any of its subsidiaries or affiliates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationDestination(for: ContentRoute.self) { route in
                switch route {
                case .templates:
                    TemplatesView()
                case .howHazelWorks:
                    HowHazelWorksView()
                case .pendingQueue:
                    PendingQueueView()
                case .transactionDrafts:
                    TransactionDraftsView()
                case .continueDraft(let draftId):
                    ContinueDraftView(draftId: draftId)
                }
            }
        }
        // Picks up a token invalidated by an App Intent (e.g. an expired
        // YNAB token found while running a Shortcut) while this view's
        // YNABAuthService instance was already alive.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                ynabAuth.refreshFromKeychain()
                splitwiseAuth.refreshFromKeychain()
                Task { await pendingQueue.flush() }
                draftCount = TransactionDraftStore.load().count
            }
        }
        // Needed so TransactionDraftGuard's "Ensure Completion" reminders
        // can actually be delivered — requesting more than once is a no-op
        // once the user has already answered the system prompt.
        .task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        // A tapped draft notification always jumps straight to that draft's
        // continue flow, resetting whatever else was on the stack — it's a
        // deliberate, deep-linked destination, not just "open the app".
        .onChange(of: draftRouter.pendingDraftID) { _, newValue in
            guard let newValue else { return }
            path = [.continueDraft(newValue)]
            draftRouter.pendingDraftID = nil
        }
    }
}

#Preview {
    ContentView()
}
