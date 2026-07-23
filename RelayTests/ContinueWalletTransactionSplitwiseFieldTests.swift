//
//  ContinueWalletTransactionSplitwiseFieldTests.swift
//  RelayTests
//
//  Covers the split of the Splitwise draft's single field into a Payee field
//  (the merchant's clean name, stored on the merchant→template mapping) and a
//  Description field (the expense text, defaulting to the payee). The key
//  behaviors: a blank Payee falls back to the raw merchant, and a blank
//  Description falls back to the effective payee — so doing nothing on a
//  shortcut-started draft reproduces the old single-field behavior.
//

import Foundation
import Testing
@testable import Relay

@MainActor
struct ContinueWalletTransactionSplitwiseFieldTests {
    private static let merchant = "REWE SAGT DANKE 1234 //BERLIN/DE"

    private static func splitwiseDraftModel() -> ContinueWalletTransactionModel {
        let draft = TransactionDraft(
            id: UUID(),
            startedAt: Date(),
            payload: .splitwiseWallet(merchant: merchant, amount: 32.10)
        )
        // isAuthenticatedOverride skips the Keychain gate so init runs the
        // real config-resolution path against an (empty) test config.
        return ContinueWalletTransactionModel(draft: draft, isAuthenticatedOverride: true)
    }

    @Test
    func blankFieldsFallBackToMerchantForBothPayeeAndDescription() {
        let model = Self.splitwiseDraftModel()
        // Unknown merchant → Payee starts blank so its placeholder shows.
        #expect(model.payeeText.isEmpty)
        #expect(model.descriptionText.isEmpty)

        // Leaving everything untouched files the expense under the raw
        // merchant, matching the pre-split single-field behavior.
        #expect(model.splitwisePayeeName == Self.merchant)
        #expect(model.splitwiseDescription == Self.merchant)
    }

    @Test
    func typedPayeeDrivesBothTheMappingNameAndTheDescriptionDefault() {
        let model = Self.splitwiseDraftModel()
        model.payeeText = "  Rewe  "

        // Payee is trimmed and used as the merchant's clean name...
        #expect(model.splitwisePayeeName == "Rewe")
        // ...and the description mirrors it while its own field is blank.
        #expect(model.splitwiseDescription == "Rewe")
    }

    @Test
    func typedDescriptionOverridesOnlyTheExpenseTextNotThePayee() {
        let model = Self.splitwiseDraftModel()
        model.payeeText = "Rewe"
        model.descriptionText = "  Weekly groceries  "

        // The Description field wins for the expense text (trimmed)...
        #expect(model.splitwiseDescription == "Weekly groceries")
        // ...while the payee/mapping name stays independent.
        #expect(model.splitwisePayeeName == "Rewe")
    }

    @Test
    func descriptionWithoutAPayeeStillFallsBackToTheMerchant() {
        let model = Self.splitwiseDraftModel()
        // Payee left blank, only a description typed.
        model.descriptionText = "Dinner"

        #expect(model.splitwisePayeeName == Self.merchant)
        #expect(model.splitwiseDescription == "Dinner")
    }

    @Test
    func blankShortcutDraftIsStillSubmittableSincePayeeFallsBackToMerchant() {
        let model = Self.splitwiseDraftModel()
        // A shortcut draft always resolves a non-empty description via the
        // merchant, so an empty description never blocks submit on its own.
        #expect(!model.splitwiseDescription.isEmpty)
    }
}
