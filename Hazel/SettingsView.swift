//
//  SettingsView.swift
//  Hazel
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @State private var ynabAuth = YNABAuthService()
    @State private var splitwiseAuth = SplitwiseAuthService()
    @State private var notificationsEnabled = NotificationsPreferenceStore.isEnabled
    @State private var showBucketFileImporter = false
    @State private var isImportingBuckets = false
    @State private var bucketImportResultMessage: String?
    @State private var bucketImportErrorMessage: String?
    @State private var showTemplateExporter = false
    @State private var templateExportDocument: JSONFileDocument?
    @State private var templateExportResultMessage: String?
    @State private var templateExportErrorMessage: String?
    #if DEBUG
    @State private var showOnboardingPreview = false
    #endif
    @State private var migration = LegacyMigrationCallbackHandler()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AccountConnectionRow(
                        title: "YNAB",
                        isConnected: ynabAuth.isAuthenticated,
                        connect: ynabAuth.signIn,
                        disconnect: ynabAuth.signOut
                    )

                    AccountConnectionRow(
                        title: "Splitwise",
                        isConnected: splitwiseAuth.isAuthenticated,
                        connect: splitwiseAuth.signIn,
                        disconnect: splitwiseAuth.signOut
                    )

                    if splitwiseAuth.isAuthenticated {
                        DefaultSplitwiseFriendRow()
                    }
                }
                .cardRowBackground()

                Section {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            NotificationsPreferenceStore.isEnabled = newValue
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                } footer: {
                    Text("Used to remind you if a wallet transaction is left unfinished or a queued transaction is still waiting to sync, so nothing silently gets lost.")
                        .footerText()
                }
                .tint(.accentColor)
                .cardRowBackground()

                Section {
                    Button("Import Templates") {
                        showBucketFileImporter = true
                    }
                    .disabled(isImportingBuckets)
                    if isImportingBuckets {
                        ProgressView()
                    }
                    if let bucketImportResultMessage {
                        Text(bucketImportResultMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let bucketImportErrorMessage {
                        Text(bucketImportErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Imports a JSON file exported from here, or the legacy shape the \"YNAB Toolkit\" Shortcut's DataJar config used.")
                        .footerText()
                }
                .cardRowBackground()

                Section {
                    Button("Install Shortcut") {
                        openURL(LegacyBucketMigrationShortcut.installURL, prefersInApp: true)
                    }
                    Button("Run Migration") {
                        migration.reset()
                        openURL(LegacyBucketMigrationShortcut.runURL)
                    }
                    if let resultMessage = migration.resultMessage {
                        Text(resultMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Install the \"\(LegacyBucketMigrationShortcut.name)\" Shortcut once, then run it here to pull buckets and merchants straight out of the old \"Transaction → YNAB\" Shortcut's DataJar storage.")
                        .footerText()
                }
                .cardRowBackground()

                Section {
                    Button("Export Templates") {
                        exportTemplates()
                    }
                    if let templateExportResultMessage {
                        Text(templateExportResultMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let templateExportErrorMessage {
                        Text(templateExportErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Saves your templates, auto-match rules, merchants, and cards as a JSON file — a full backup you can re-import here later, including into a different device.")
                        .footerText()
                }
                .cardRowBackground()
                
                Section {
                    NavigationLink(value: SettingsRoute.howHazelWorks) {
                        RowLabel(title: "How Hazel Works")
                    }
                } footer: {
                    // Required by the YNAB API Terms of Service.
                    Text("We are not affiliated, associated, or in any way officially connected with YNAB or any of its subsidiaries or affiliates.")
                        .footerText()
                }
                .cardRowBackground()

                #if DEBUG
                Section("Debug") {
                    Button("Show Onboarding") {
                        showOnboardingPreview = true
                    }
                }
                .cardRowBackground()
                #endif
            }
            .themedList(background: .sheetBackgroundColor)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .howHazelWorks:
                    HowHazelWorksView()
                }
            }
            .fileImporter(isPresented: $showBucketFileImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .failure(let error):
                    bucketImportResultMessage = nil
                    bucketImportErrorMessage = "Failed to import: \(error.localizedDescription)"
                case .success(let url):
                    Task { await importBuckets(from: url) }
                }
            }
            .fileExporter(
                isPresented: $showTemplateExporter,
                document: templateExportDocument,
                contentType: .json,
                defaultFilename: "Hazel Templates"
            ) { result in
                switch result {
                case .success:
                    templateExportErrorMessage = nil
                    templateExportResultMessage = "Exported."
                case .failure(let error):
                    templateExportResultMessage = nil
                    templateExportErrorMessage = "Failed to export: \(error.localizedDescription)"
                }
            }
            #if DEBUG
            .sheet(isPresented: $showOnboardingPreview) {
                OnboardingView()
            }
            #endif
            .legacyMigrationCallback(migration, openURL: openURL)
        }
    }

    // Requesting more than once is a no-op once the user has already
    // answered the system prompt, so switching the toggle on again after a
    // denial just does nothing rather than needing its own branch.
    private func requestNotificationPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    private func importBuckets(from url: URL) async {
        bucketImportResultMessage = nil
        bucketImportErrorMessage = nil
        isImportingBuckets = true
        defer { isImportingBuckets = false }

        switch await TemplateImportService.importBuckets(from: url) {
        case .success(let message):
            bucketImportResultMessage = message
        case .failure(let error):
            bucketImportErrorMessage = error.message
        }
    }

    private func exportTemplates() {
        templateExportResultMessage = nil
        templateExportErrorMessage = nil
        let config = WalletTransactionConfigStore.load()
        let encoder = JSONEncoder()
        // Human-readable and byte-stable across exports of unchanged data —
        // this is a backup file a user might open/diff by hand, not a wire
        // format, so there's no cost to spending the extra whitespace.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else {
            templateExportErrorMessage = "Failed to export: couldn't encode templates."
            return
        }
        templateExportDocument = JSONFileDocument(data: data)
        showTemplateExporter = true
    }
}

/// Minimal FileDocument wrapper so `.fileExporter` can save arbitrary JSON
/// `Data` — Hazel never reads a document back through this type, only
/// writes, since import goes through `.fileImporter` + JSONDecoder instead.
private struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum SettingsRoute: Hashable {
    case howHazelWorks
}

#Preview {
    SettingsView()
}
