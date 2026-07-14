//
//  YNABCategoryUsageStore.swift
//  Hazel
//
//  Tracks when each YNAB category was last used on a created transaction
//  (recorded from AddYNABTransactionIntent/AddWalletTransactionToYNABIntent),
//  so category pickers — Shortcuts' native one via YNABCategoryQuery, and
//  the wallet intent's requestDisambiguation prompt — surface recently-used
//  categories first instead of whatever order the YNAB API returns.
//  Mirrors SplitwiseFriendUsageStore.swift's approach exactly.
//

import Foundation

struct YNABCategoryUsage: Codable {
    var lastUsedByCategoryId: [String: Date] = [:]
}

nonisolated enum YNABCategoryUsageStore {
    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ynab-category-usage.json")
    }()

    static func load() -> YNABCategoryUsage {
        guard let data = try? Data(contentsOf: fileURL) else { return YNABCategoryUsage() }
        return (try? JSONDecoder().decode(YNABCategoryUsage.self, from: data)) ?? YNABCategoryUsage()
    }

    static func recordUsage(categoryId: String) {
        var usage = load()
        usage.lastUsedByCategoryId[categoryId] = Date()
        guard let data = try? JSONEncoder().encode(usage) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Most-recently-used first; categories with no recorded usage keep
    /// their original (YNAB API) relative order, appended after all used ones.
    static func sorted(_ categories: [YNABCategory]) -> [YNABCategory] {
        let lastUsed = load().lastUsedByCategoryId
        return categories.enumerated()
            .sorted { lhs, rhs in
                let lhsDate = lastUsed[lhs.element.id]
                let rhsDate = lastUsed[rhs.element.id]
                switch (lhsDate, rhsDate) {
                case let (l?, r?): return l > r
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }
}
