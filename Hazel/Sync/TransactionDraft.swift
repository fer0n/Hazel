//
//  TransactionDraft.swift
//  Hazel
//
//  A wallet transaction/expense that's been started (Merchant/Amount seen)
//  but not yet confirmed created — tracked by TransactionDraftGuard so the
//  wallet automations' "Ensure Completion" parameter can nudge the user
//  with a notification if the run gets interrupted before finishing.
//

import Foundation

struct TransactionDraft: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let summary: String
    let service: Service

    enum Service: String, Codable {
        case ynab
        case splitwise

        var displayName: String {
            switch self {
            case .ynab: "YNAB"
            case .splitwise: "Splitwise"
            }
        }
    }
}
