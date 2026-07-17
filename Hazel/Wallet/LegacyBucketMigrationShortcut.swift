//
//  LegacyBucketMigrationShortcut.swift
//  Hazel
//
//  Handoff to the "YNAB Toolkit → Hazel" Shortcut, which reads the old
//  "Transaction → YNAB" Shortcut's DataJar buckets/merchants/cards and hands
//  them to Hazel's Import Template File action. Hazel only needs to open the
//  shortcut and listen for its x-callback-url completion — the parsing and
//  import themselves happen inside the Shortcut, not here.
//

import Foundation

enum LegacyBucketMigrationShortcut {
    static let name = "YNAB Toolkit → Hazel"
    static let installURL = URL(string: "https://www.icloud.com/shortcuts/a48f426a7eb74aeea2fc98df99ac1e47")!

    /// Hosts used on the "hazel://" scheme already registered for OAuth — a
    /// Shortcut run via x-callback-url opens x-success on completion or
    /// x-error (with an "errorMessage" query item attached automatically by
    /// iOS) if it fails or is cancelled.
    static let successHost = "legacy-migration-success"
    static let errorHost = "legacy-migration-error"

    static var runURL: URL {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: "hazel://\(successHost)"),
            URLQueryItem(name: "x-error", value: "hazel://\(errorHost)"),
        ]
        return components.url!
    }
}
