//
//  TransactionDraftsView.swift
//  Hazel
//
//  Lists whatever TransactionDraftGuard still considers "started but not
//  finished". Tapping one pushes ContinueDraftView to actually finish it —
//  the same flow a tapped notification opens — since there's no way to
//  resume the original suspended App Intent perform() call; dismissing one
//  instead just clears the draft and cancels its notification without
//  finishing anything.
//

import SwiftUI

struct TransactionDraftsView: View {
    @State private var drafts: [TransactionDraft] = TransactionDraftStore.load()

    var body: some View {
        List {
            if drafts.isEmpty {
                ContentUnavailableView(
                    "Nothing Open",
                    systemImage: "checkmark.circle",
                    description: Text("No wallet transactions are waiting to be finished.")
                )
            } else {
                ForEach(drafts) { draft in
                    NavigationLink(value: ContentRoute.continueDraft(draft.id)) {
                        TransactionDraftRow(draft: draft)
                    }
                    .swipeActions {
                        Button("Dismiss", role: .destructive) {
                            TransactionDraftGuard.complete(draft.id)
                            drafts.removeAll { $0.id == draft.id }
                        }
                    }
                }
            }
        }
        .navigationTitle("Transaction Drafts")
        .task {
            drafts = TransactionDraftStore.load()
        }
    }
}

private struct TransactionDraftRow: View {
    let draft: TransactionDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    draft.service.displayName,
                    systemImage: draft.service == .ynab ? "banknote" : "person.2"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Text(draft.startedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(draft.summary)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TransactionDraftsView()
    }
}
