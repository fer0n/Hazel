//
//  TransactionDetailView.swift
//  Relay
//
//  Unified detail screen for a single transaction, reached two ways:
//
//  - `.draft(id:)` — a tapped "Continue Adding Transaction" notification (or
//    a draft row in TransactionDraftsView): loads the draft by id and routes
//    to the editable continue flow (ContinueWalletTransactionView), or
//    explains there's nothing left to do if it's already been resolved
//    (completed elsewhere, or dismissed) since the notification fired.
//  - `.history(_:)` — a tapped row in ContentView's "Recent" list: a
//    read-only summary of an already-created YNAB transaction and/or
//    Splitwise expense. No editing — re-adding stays on the row's context
//    menu.
//  - `.pending(_:)` — a tapped row in PendingQueueView: a read-only summary
//    of a YNAB transaction or Splitwise expense still waiting to be sent.
//    Retry/delete stay on the row's swipe actions.
//

import SwiftUI

struct TransactionDetailView: View {
    enum Source {
        case draft(id: UUID)
        case history(TransactionHistoryEntry)
        case pending(PendingOperation)
    }

    let source: Source

    var body: some View {
        switch source {
        case .draft(let id):
            DraftDetailContent(draftId: id)
        case .history(let entry):
            HistoryDetailContent(entry: entry)
        case .pending(let operation):
            PendingDetailContent(operation: operation)
        }
    }
}

// MARK: - Draft (editable continue flow)

private struct DraftDetailContent: View {
    let draftId: UUID

    @State private var draft: TransactionDraft?
    @State private var isLoaded = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let draft {
                ContinueWalletTransactionView(draft: draft, onDiscard: delete)
            } else if isLoaded {
                ContentUnavailableView(
                    "Already Handled",
                    systemImage: "checkmark.circle",
                    description: Text("This transaction was already completed or dismissed.")
                )
            } else {
                ProgressView()
            }
        }
        .task {
            draft = TransactionDraftStore.load().first { $0.id == draftId }
            isLoaded = true
        }
    }

    private func delete() {
        guard let draft else { return }
        TransactionDraftGuard.complete(draft.id)
        dismiss()
    }
}

// MARK: - Shared read-only layout

/// Hero amount/service/subtitle/timestamp header, plus caller-supplied detail
/// sections — the common shell behind `HistoryDetailContent` and
/// `PendingDetailContent`.
private struct ReadOnlyDetailContent<Sections: View>: View {
    let amount: String
    let serviceIcons: [String]
    let subtitle: String
    let timestamp: Text
    /// Called when the user confirms "Discard". Nil hides the section
    /// entirely (e.g. history, which can't be discarded).
    var onDiscard: (() -> Void)? = nil
    @ViewBuilder var sections: () -> Sections

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text(amount)
                        .foregroundStyle(Color.foregroundColor)
                        .fontWeight(.heavy)
                        .font(.system(size: 50))
                        .minimumScaleFactor(0.5)
                    HStack(spacing: 6) {
                        ForEach(serviceIcons, id: \.self) { icon in
                            Image(systemName: icon)
                        }
                        Text(subtitle)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    timestamp
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.sheetBackgroundColor)

            sections()

            if let onDiscard {
                DiscardSection(confirmationTitle: "Discard this transaction?", onDiscard: onDiscard)
            }
        }
        .themedList(background: .sheetBackgroundColor)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - History (read-only)

private struct HistoryDetailContent: View {
    let entry: TransactionHistoryEntry

    private var titleLabel: LocalizedStringKey {
        entry.service == .ynab ? "Payee" : "Description"
    }

    var body: some View {
        ReadOnlyDetailContent(
            amount: entry.formattedAmount,
            serviceIcons: [entry.service.systemImage] + (entry.secondaryService.map { [$0.systemImage] } ?? []),
            subtitle: entry.title,
            timestamp: Text("Added \(RelativeDateTimeFormatter().localizedString(for: entry.createdAt, relativeTo: Date()))")
        ) {
            Section {
                DraftDetailRow(icon: "text.alignleft", title: titleLabel) {
                    Text(entry.title)
                }
                .cardRowBackground()

                if let categoryName = entry.categoryName {
                    DraftDetailRow(icon: "tag.fill", title: "Category") {
                        Text(categoryName)
                    }
                    .cardRowBackground()
                }

                if let accountName = entry.accountName {
                    DraftDetailRow(icon: "creditcard.fill", title: "Account") {
                        Text(accountName)
                    }
                    .cardRowBackground()
                }
            }

            if let splitSummary = entry.splitSummary {
                Section("Split") {
                    DraftDetailRow(icon: "person.2.fill", title: "With") {
                        Text(splitSummary)
                    }
                    .cardRowBackground()
                }
            }
        }
    }
}

// MARK: - Pending (read-only)

private struct PendingDetailContent: View {
    let operation: PendingOperation

    @Environment(\.dismiss) private var dismiss

    private var titleLabel: LocalizedStringKey {
        operation.service == .ynab ? "Payee" : "Description"
    }

    var body: some View {
        ReadOnlyDetailContent(
            amount: operation.payload.formattedAmount,
            serviceIcons: [operation.service.systemImage],
            subtitle: operation.payload.title,
            timestamp: Text("Queued \(RelativeDateTimeFormatter().localizedString(for: operation.queuedAt, relativeTo: Date()))"),
            onDiscard: discard
        ) {
            Section {
                DraftDetailRow(icon: "text.alignleft", title: titleLabel) {
                    Text(operation.payload.title)
                }
                .cardRowBackground()

                if let detail = operation.payload.detail {
                    DraftDetailRow(icon: operation.service == .ynab ? "tag.fill" : "person.2.fill", title: operation.service == .ynab ? "Category" : "With") {
                        Text(detail)
                    }
                    .cardRowBackground()
                }
            }

            if let lastError = operation.lastError {
                Section("Last Error") {
                    DraftDetailRow(icon: "exclamationmark.triangle.fill", title: "Attempt \(operation.attemptCount)") {
                        Text(lastError)
                    }
                    .cardRowBackground()
                }
            }
        }
    }

    private func discard() {
        PendingOperationQueue.shared.delete(id: operation.id)
        dismiss()
    }
}

#Preview("Draft") {
    let draft = TransactionDraft(
        id: UUID(),
        startedAt: Date().addingTimeInterval(-3600),
        payload: .ynabWallet(merchant: "Coffee Shop", amount: 4.50, card: "Visa")
    )
    Color.clear
        .onAppear { try? TransactionDraftStore.save([draft]) }
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                TransactionDetailView(source: .draft(id: draft.id))
            }
        }
}

#Preview("History") {
    let entry = TransactionHistoryEntry(
        id: UUID(),
        createdAt: Date().addingTimeInterval(-3600),
        summary: "12.34 at Coffee Shop",
        payload: .ynabTransaction(YNABTransactionRequest(
            accountId: "acct",
            date: "2026-07-21",
            amount: -12340,
            payeeName: "Coffee Shop",
            categoryId: nil,
            cleared: "cleared",
            approved: true
        ))
    )
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                TransactionDetailView(source: .history(entry))
            }
        }
}
