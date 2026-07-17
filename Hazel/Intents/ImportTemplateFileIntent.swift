//
//  ImportTemplateFileIntent.swift
//  Hazel
//
//  Siri/Shortcuts equivalent of Settings' "Import Templates" button — lets a
//  Shortcut hand Hazel a templates JSON file directly, e.g. one pulled
//  straight out of Data Jar via "Get Value for Key", without an intermediate
//  Save File step: Shortcuts coerces non-file output (text, dictionaries)
//  into an ephemeral IntentFile automatically when a parameter is typed as
//  File. Reuses the exact same TemplateImportService as the in-app button.
//

import AppIntents
import UniformTypeIdentifiers

nonisolated struct ImportTemplateFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Template File"
    static let description = IntentDescription("Imports a Hazel templates JSON file, or the legacy shape the \"YNAB Toolkit\" Shortcut's DataJar config used.")

    @Parameter(title: "File", supportedContentTypes: [.json, .data])
    var file: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$file) as templates")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch await TemplateImportService.importBuckets(from: file.data) {
        case .success(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .failure(let error):
            throw TemplateImportIntentError.importFailed(error.message)
        }
    }
}

enum TemplateImportIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case importFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .importFailed(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }
}
