//
//  ContinueDraftView.swift
//  Hazel
//
//  Entry point for a tapped draft notification (or a tap in
//  TransactionDraftsView): loads the draft by id and routes to the matching
//  continue flow, or explains there's nothing left to do if it's already
//  been resolved (completed elsewhere, or dismissed) since the notification
//  fired.
//

import SwiftUI

struct ContinueDraftView: View {
    let draftId: UUID

    @State private var draft: TransactionDraft?
    @State private var isLoaded = false

    var body: some View {
        Group {
            if let draft {
                switch draft.service {
                case .ynab:
                    ContinueYNABWalletTransactionView(draft: draft)
                case .splitwise:
                    ContinueSplitwiseWalletTransactionView(draft: draft)
                }
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
}
