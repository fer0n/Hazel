//
//  OnboardingWelcomePage.swift
//  Relay
//

import SwiftUI

struct OnboardingWelcomePage: View {
    let ynabAuth: YNABAuthService
    let splitwiseAuth: SplitwiseAuthService

    var body: some View {
        List {
            Section {
                AccountConnectionRow(
                    title: "YNAB",
                    isConnected: ynabAuth.isAuthenticated,
                    connect: ynabAuth.signIn,
                    disconnect: ynabAuth.signOut,
                    highlightWhenDisconnected: true
                )

                AccountConnectionRow(
                    title: "Splitwise",
                    isConnected: splitwiseAuth.isAuthenticated,
                    connect: splitwiseAuth.signIn,
                    disconnect: splitwiseAuth.signOut,
                    highlightWhenDisconnected: true
                )

                if splitwiseAuth.isAuthenticated {
                    DefaultSplitwiseFriendRow()
                }
            }
            .cardRowBackground()
        }
        .themedList(background: .sheetBackgroundColor)
        .alert(
            "Couldn't Connect to YNAB",
            isPresented: Binding(
                get: { ynabAuth.signInError != nil },
                set: { if !$0 { ynabAuth.clearSignInError() } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(ynabAuth.signInError ?? "")
        }
        .alert(
            "Couldn't Connect to Splitwise",
            isPresented: Binding(
                get: { splitwiseAuth.signInError != nil },
                set: { if !$0 { splitwiseAuth.clearSignInError() } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(splitwiseAuth.signInError ?? "")
        }
    }
}

#Preview {
    OnboardingWelcomePage(ynabAuth: YNABAuthService(), splitwiseAuth: SplitwiseAuthService())
}
