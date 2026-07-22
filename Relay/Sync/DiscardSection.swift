//
//  DiscardSection.swift
//  Relay
//
//  Shared "Discard" row — a centered, secondary-styled button gated behind a
//  destructive confirmationDialog. Used by both the editable continue flow
//  (ContinueWalletTransactionView) and the read-only detail views
//  (TransactionDetailView's PendingDetailContent).
//

import SwiftUI

struct DiscardSection: View {
    let confirmationTitle: LocalizedStringKey
    let onDiscard: () -> Void

    @State private var showDiscardConfirmation = false

    var body: some View {
        Section {
            Button("Discard") {
                showDiscardConfirmation = true
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .confirmationDialog(
                confirmationTitle,
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Confirm", role: .destructive, action: onDiscard)
            }
        }
        .cardRowBackground()
    }
}
