//
//  PendingQueueView.swift
//  Hazel
//
//  Shows everything PendingOperationQueue is still waiting to send to YNAB
//  or Splitwise (queued because the device was offline when an intent ran),
//  with manual retry/delete since there's no OS-level background sync — see
//  PendingOperationQueue's header comment.
//

import SwiftUI

struct PendingQueueView: View {
    @State private var queue = PendingOperationQueue.shared
    @State private var isFlushing = false

    var body: some View {
        List {
            if queue.operations.isEmpty {
                ContentUnavailableView(
                    "All Synced",
                    systemImage: "checkmark.circle",
                    description: Text("Nothing is waiting to be sent to YNAB or Splitwise.")
                )
            } else {
                ForEach(queue.operations) { operation in
                    PendingOperationRow(operation: operation)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                queue.delete(id: operation.id)
                            }
                            Button("Retry") {
                                Task { await queue.retryNow(id: operation.id) }
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Pending Queue")
        .toolbar {
            if !queue.operations.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            isFlushing = true
                            await queue.flush()
                            isFlushing = false
                        }
                    } label: {
                        if isFlushing {
                            ProgressView()
                        } else {
                            Text("Retry All")
                        }
                    }
                    .disabled(isFlushing)
                }
            }
        }
        .task {
            await queue.flush()
        }
    }
}

private struct PendingOperationRow: View {
    let operation: PendingOperation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    operation.service == .ynab ? "YNAB" : "Splitwise",
                    systemImage: operation.service == .ynab ? "banknote" : "person.2"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Text(operation.queuedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(operation.summary)
                .font(.body)
            if let lastError = operation.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PendingQueueView()
    }
}
