//
//  DraftDetailRow.swift
//  Hazel
//
//  Shared row style for ContinueYNABWalletTransactionView and
//  ContinueSplitwiseWalletTransactionView's detail/split sections: icon +
//  label on the left, value/control trailing on the right.
//

import SwiftUI

struct DraftDetailRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
            Spacer()
            content()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    List {
        Section {
            DraftDetailRow(icon: "text.alignleft", title: "Description") {
                Text("Grocery Store")
            }
            .cardRowBackground()

            DraftDetailRow(icon: "doc.on.doc", title: "Template") {
                Text("New")
            }
            .cardRowBackground()

            DraftDetailRow(icon: "person.2", title: "Provider") {
                Text("Splitwise")
            }
            .cardRowBackground()
        }
    }
    .themedList(background: .backgroundColor)
}
