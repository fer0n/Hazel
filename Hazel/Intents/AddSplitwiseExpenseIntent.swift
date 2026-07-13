//
//  AddSplitwiseExpenseIntent.swift
//  Hazel
//
//  Siri/Shortcuts equivalent of the "Splitwise Master" Shortcut being
//  replaced (see docs/project-goals.md). Fields mirror that shortcut: cost,
//  description, and an optional own share (splits the cost equally with
//  the chosen friend when left blank). The signed-in user always pays the
//  full cost up front and is owed back the friend's share.
//

import AppIntents

nonisolated struct AddSplitwiseExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Splitwise Expense"
    static let description = IntentDescription("Adds an expense split with a friend on Splitwise.")

    @Parameter(title: "Amount", description: "The total expense amount, e.g. 12.34")
    var amount: Double

    @Parameter(title: "Description")
    var expenseDescription: String

    @Parameter(title: "Split With")
    var friend: SplitwiseFriendEntity

    @Parameter(title: "Your Share", description: "Leave blank to split the cost equally")
    var ownShare: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) expense for \(\.$expenseDescription) split with \(\.$friend)") {
            \.$ownShare
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = SplitwiseAuthService.currentAccessToken else {
            throw SplitwiseIntentError.notAuthenticated
        }

        do {
            let user = try await SplitwiseService.fetchCurrentUser(token: token)

            let costCents = Int((amount * 100).rounded())
            let ownShareCents = ownShare.map { Int(($0 * 100).rounded()) } ?? costCents / 2
            let friendShareCents = costCents - ownShareCents

            let expense = SplitwiseExpenseRequest(
                costCents: costCents,
                description: expenseDescription,
                currencyCode: "EUR",
                payerUserId: user.id,
                payerOwedCents: ownShareCents,
                friendUserId: friend.id,
                friendOwedCents: friendShareCents
            )
            try await SplitwiseService.createExpense(expense, token: token)

            let ownAmount = (Double(ownShareCents) / 100).formatted(.number.precision(.fractionLength(2)))
            let friendAmount = (Double(friendShareCents) / 100).formatted(.number.precision(.fractionLength(2)))
            return .result(dialog: "Added \(expenseDescription) — you: \(ownAmount), \(friend.name): \(friendAmount)")
        } catch {
            throw SplitwiseIntentError.from(error)
        }
    }
}
