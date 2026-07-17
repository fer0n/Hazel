//
//  ContentView.swift
//  Hazel
//

import SwiftUI

struct ContentView: View {
    @State private var pendingQueue = PendingOperationQueue.shared
    @State private var draftRouter = DraftNotificationRouter.shared
    @State private var drafts = TransactionDraftStore.load()
    @State private var splitwiseImportCount = SplitwiseFileImportStagingStore.load()?.rows.count ?? 0
    @State private var history = TransactionHistoryStore.load()
    @State private var readdAlert: ReaddAlert?
    @State private var path: [ContentRoute] = []
    @State private var showSettings = false
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    private struct ReaddAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Shared by every conditionally-shown row/section below so they
    /// animate in/out together instead of just popping.
    private static let rowTransition = AnyTransition.opacity.combined(with: .move(edge: .top))

    /// Most recently started 3 drafts — "Show All" links to the full list
    /// (TransactionDraftsView) for everything else.
    private var topDrafts: [TransactionDraft] {
        Array(drafts.sorted { $0.startedAt > $1.startedAt }.prefix(3))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .opacity(0.8)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.backgroundColor)
                
                Section {
                    NavigationLink(value: ContentRoute.templates) {
                        RowLabel(title: "Templates", systemImage: "doc.on.doc")
                    }
                }
                .cardRowBackground()

                if pendingQueue.operations.count > 0 {
                    NavigationLink(value: ContentRoute.pendingQueue) {
                        RowLabel(title: "Pending Queue", systemImage: "arrow.triangle.2.circlepath", badge: pendingQueue.operations.count)
                    }
                    .cardRowBackground()
                    .transition(Self.rowTransition)
                }

                if splitwiseImportCount > 0 {
                    NavigationLink(value: ContentRoute.splitwiseFileImport) {
                        RowLabel(title: "Splitwise Import", systemImage: "person.2.badge.plus", badge: splitwiseImportCount)
                    }
                    .cardRowBackground()
                    .transition(Self.rowTransition)
                }
                
                if !drafts.isEmpty {
                    Section("Drafts") {
                        ForEach(topDrafts) { draft in
                            NavigationLink(value: ContentRoute.continueDraft(draft.id)) {
                                TransactionSummaryRow(service: draft.service, date: draft.startedAt, title: draft.merchant, amount: draft.formattedAmount, showChevron: true)
                            }
                            .cardRowBackground()
                            .swipeActions {
                                Button("Dismiss", role: .destructive) {
                                    TransactionDraftGuard.complete(draft.id)
                                    withAnimation {
                                        drafts.removeAll { $0.id == draft.id }
                                    }
                                }
                            }
                        }
                        if drafts.count > topDrafts.count {
                            NavigationLink(value: ContentRoute.transactionDrafts) {
                                RowLabel(title: "Show All", systemImage: "square.and.pencil")
                            }
                            .cardRowBackground()
                        }
                    }
                    .transition(Self.rowTransition)
                }

                if !history.isEmpty {
                    Section("Recent") {
                        ForEach(history) { entry in
                            TransactionSummaryRow(
                                service: entry.service,
                                date: entry.createdAt,
                                title: entry.payload.title,
                                amount: entry.payload.formattedAmount,
                                detail: entry.payload.detail
                            )
                                .cardRowBackground()
                                .contextMenu {
                                    Button {
                                        readd(entry)
                                    } label: {
                                        Label("Re-add", systemImage: "arrow.clockwise")
                                    }
                                }
                        }
                    }
                    .transition(Self.rowTransition)
                }
            }
            .themedList(background: .backgroundColor)
            .navigationDestination(for: ContentRoute.self) { route in
                switch route {
                case .templates:
                    TemplatesView()
                case .pendingQueue:
                    PendingQueueView()
                case .transactionDrafts:
                    TransactionDraftsView()
                case .continueDraft(let draftId):
                    ContinueDraftView(draftId: draftId)
                case .splitwiseFileImport:
                    SplitwiseFileImportReviewView()
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button {
                    showSettings = true
                } label: {
                    Text("Settings")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .themedText()
                }
                .buttonStyle(.glass)
            }
        }
        // Picks up a token invalidated by an App Intent (e.g. an expired
        // YNAB token found while running a Shortcut) while this view's
        // YNABAuthService instance was already alive.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await pendingQueue.flush() }
                withAnimation {
                    drafts = TransactionDraftStore.load()
                    splitwiseImportCount = SplitwiseFileImportStagingStore.load()?.rows.count ?? 0
                    history = TransactionHistoryStore.load()
                }
            }
        }
        // A tapped draft notification always jumps straight to that draft's
        // continue flow, resetting whatever else was on the stack — it's a
        // deliberate, deep-linked destination, not just "open the app".
        .onChange(of: draftRouter.pendingDraftID) { _, newValue in
            guard let newValue else { return }
            path = [.continueDraft(newValue)]
            draftRouter.pendingDraftID = nil
        }
        // Same deep-link pattern as the draft notification above.
        .onChange(of: draftRouter.pendingQueueReminderTapped) { _, tapped in
            guard tapped else { return }
            path = [.pendingQueue]
            draftRouter.pendingQueueReminderTapped = false
        }
        // ImportSplitwiseFileIntent brought Hazel to the foreground itself
        // (see its supportedModes) specifically to land here — same
        // deep-link pattern, just triggered by the intent instead of a
        // tapped notification.
        .onChange(of: draftRouter.pendingSplitwiseImport) { _, pending in
            guard pending else { return }
            path = [.splitwiseFileImport]
            draftRouter.pendingSplitwiseImport = false
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: Self.hasLaunchedBeforeKey) {
                UserDefaults.standard.set(true, forKey: Self.hasLaunchedBeforeKey)
                showOnboarding = true
            }
            // Reappearing here also covers popping back from a pushed
            // ContinueDraftView after it dismisses itself on completion —
            // that path never triggers the scenePhase handler below.
            withAnimation {
                drafts = TransactionDraftStore.load()
                splitwiseImportCount = SplitwiseFileImportStagingStore.load()?.rows.count ?? 0
                history = TransactionHistoryStore.load()
            }
        }
        .alert(
            readdAlert?.title ?? "",
            isPresented: Binding(get: { readdAlert != nil }, set: { if !$0 { readdAlert = nil } }),
            presenting: readdAlert
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { alert in
            Text(alert.message)
        }
    }

    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"

    private func readd(_ entry: TransactionHistoryEntry) {
        Task {
            do {
                let outcome = try await entry.readd()
                withAnimation {
                    history = TransactionHistoryStore.load()
                }
                if case .queued = outcome {
                    readdAlert = ReaddAlert(
                        title: "Queued",
                        message: "You're offline — this will sync automatically once you're back online."
                    )
                }
            } catch {
                let message = (error as? YNABIntentError).map { String(localized: $0.localizedStringResource) }
                    ?? (error as? SplitwiseIntentError).map { String(localized: $0.localizedStringResource) }
                    ?? "Couldn't re-add the transaction."
                readdAlert = ReaddAlert(title: "Couldn't Re-add", message: message)
            }
        }
    }
}

#Preview {
    ContentView()
}
