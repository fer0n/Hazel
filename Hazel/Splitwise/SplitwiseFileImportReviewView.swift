//
//  SplitwiseFileImportReviewView.swift
//  Hazel
//
//  Where ImportSplitwiseFileIntent's parsed-but-not-yet-split rows actually
//  get turned into Splitwise expenses — the multi-select step AppIntents
//  itself can't drive (see ImportSplitwiseFileIntent's header comment).
//  Rows already recorded in SplitwiseImportHistoryStore (from a previous
//  overlapping import) are flagged but still selectable, since re-splitting
//  on purpose is a valid choice, not an error.
//
//  Uses native List(selection:) + edit mode (iOS) for the checklist rather
//  than a custom checkmark row: it's a full-width tap target and an
//  unanimated toggle for free, with no extra work.
//

import SwiftUI

struct SplitwiseFileImportReviewView: View {
    @State private var staging: SplitwiseFileImportStaging?
    @State private var selectedIDs = Set<String>()
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    #if !os(macOS)
    @State private var editMode: EditMode = .active
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let resultMessage {
                ContentUnavailableView("Done", systemImage: "person.2.fill", description: Text(resultMessage))
            } else if let staging {
                list(for: staging)
            } else {
                emptyList
            }
        }
        .navigationTitle("Splitwise Import")
        .task {
            staging = SplitwiseFileImportStagingStore.load()
        }
        // ImportSplitwiseFileIntent's supportedModes brings Hazel to the
        // foreground rather than launching it fresh, so if this screen was
        // already on-screen from a previous import, .task above won't fire
        // again — reload on every foreground transition too, so a newly
        // staged import doesn't sit unseen until the user backs out and
        // back in.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                staging = SplitwiseFileImportStagingStore.load()
            }
        }
    }

    /// Same "big faint watermark icon behind an empty List" convention as
    /// TransactionDraftsView/PendingQueueView, rather than a titled
    /// ContentUnavailableView — this is "nothing staged yet", not a blocking
    /// error state like the "Done"/not-authenticated ones above.
    private var emptyList: some View {
        List {}
            .themedListStyle()
            .background {
                Color.backgroundColor
                EmptyListBackground(systemName: "doc.badge.plus")
            }
    }

    private func list(for staging: SplitwiseFileImportStaging) -> some View {
        List(selection: $selectedIDs) {
            Section("\(staging.sourceFilename) - \(staging.friendFullName)") {
                ForEach(staging.rows) { row in
                    rowContent(row)
                        .cardRowBackground()
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .themedListStyle()
        .background { Color.backgroundColor }
        #if !os(macOS)
        .environment(\.editMode, $editMode)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(selectedIDs.count == staging.rows.count ? "Deselect All" : "Select All") {
                    toggleSelectAll(rows: staging.rows)
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash.fill")
                }
                .disabled(selectedIDs.isEmpty)
                .confirmationDialog(
                    "Delete \(selectedIDs.count) selected transaction\(selectedIDs.count == 1 ? "" : "s")?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteSelected(from: staging)
                    }
                } message: {
                    Text("They'll be removed from this import without being split.")
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            Button {
                Task { await submit(staging: staging) }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Split \(selectedIDs.count) Selected")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
            }
            .buttonStyle(.glass)
            .disabled(selectedIDs.isEmpty || isSubmitting)
        }
    }

    private func rowContent(_ row: SplitwiseImportRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.payeeName).font(.body)
                Spacer()
                Text(row.amount, format: .currency(code: "EUR"))
                    .font(.body)
                    .monospacedDigit()
            }
            HStack {
                Text(row.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if SplitwiseImportHistoryStore.contains(row.id) {
                    Spacer()
                    Label("Already split", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleSelectAll(rows: [SplitwiseImportRow]) {
        if selectedIDs.count == rows.count {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(rows.map(\.id))
        }
    }

    /// Discards the selected rows from this pending import entirely — for
    /// statement lines that were never meant to be split (parsed but
    /// irrelevant), as opposed to submit(), which is the "yes, split these"
    /// path.
    private func deleteSelected(from staging: SplitwiseFileImportStaging) {
        let remainingRows = staging.rows.filter { !selectedIDs.contains($0.id) }
        let updated: SplitwiseFileImportStaging? = remainingRows.isEmpty ? nil : SplitwiseFileImportStaging(
            friendId: staging.friendId,
            friendFirstName: staging.friendFirstName,
            friendFullName: staging.friendFullName,
            rows: remainingRows,
            sourceFilename: staging.sourceFilename,
            importedAt: staging.importedAt
        )
        if let updated {
            try? SplitwiseFileImportStagingStore.save(updated)
        } else {
            SplitwiseFileImportStagingStore.clear()
        }
        withAnimation {
            selectedIDs.removeAll()
            self.staging = updated
        }
    }

    /// Sequential, not concurrent — same "don't hammer" pacing as
    /// PendingOperationQueue.flush() (300ms between calls), since Splitwise
    /// has no bulk-create endpoint to batch these into one request.
    private func submit(staging: SplitwiseFileImportStaging) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let friend = SplitwiseFriendEntity(id: staging.friendId, firstName: staging.friendFirstName, fullName: staging.friendFullName)
        let selectedRows = staging.rows.filter { selectedIDs.contains($0.id) }

        var createdCount = 0
        var queuedCount = 0
        var failedCount = 0
        var splitIds: [String] = []

        for row in selectedRows {
            do {
                let outcome = try await SplitwiseExpenseHelper.addExpense(
                    amount: row.amount,
                    description: row.payeeName,
                    friend: friend,
                    ownShare: nil,
                    date: row.date
                )
                switch outcome {
                case .created: createdCount += 1
                case .queued: queuedCount += 1
                }
                splitIds.append(row.id)
            } catch {
                failedCount += 1
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        if !splitIds.isEmpty {
            SplitwiseImportHistoryStore.recordSplit(ids: splitIds)
        }
        SplitwiseFileImportStagingStore.clear()
        self.staging = nil

        var parts: [String] = []
        if createdCount > 0 { parts.append("\(createdCount) split") }
        if queuedCount > 0 { parts.append("\(queuedCount) queued offline") }
        if failedCount > 0 { parts.append("\(failedCount) failed") }
        resultMessage = parts.isEmpty ? "Nothing selected." : parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack {
        SplitwiseFileImportReviewView()
    }
}
