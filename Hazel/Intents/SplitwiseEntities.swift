//
//  SplitwiseEntities.swift
//  Hazel
//
//  AppEntity/EntityQuery type so Siri/Shortcuts can present a live picker
//  of the signed-in user's Splitwise friends.
//

import AppIntents

nonisolated struct SplitwiseFriendEntity: AppEntity {
    let id: Int
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Splitwise Friend"
    static let defaultQuery = SplitwiseFriendQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

nonisolated struct SplitwiseFriendQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [SplitwiseFriendEntity] {
        try await allFriends().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SplitwiseFriendEntity] {
        try await allFriends()
    }

    private func allFriends() async throws -> [SplitwiseFriendEntity] {
        guard let token = SplitwiseAuthService.currentAccessToken else {
            throw SplitwiseIntentError.notAuthenticated
        }
        do {
            let friends = try await SplitwiseService.fetchFriends(token: token)
            return friends.map { SplitwiseFriendEntity(id: $0.id, name: $0.firstName) }
        } catch {
            throw SplitwiseIntentError.from(error)
        }
    }
}
