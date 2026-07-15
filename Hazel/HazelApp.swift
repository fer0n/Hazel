//
//  HazelApp.swift
//  Hazel
//

import SwiftUI

@main
struct HazelApp: App {
    init() {
        // Must happen before any notification response can arrive —
        // UNUserNotificationCenter only delivers a tap to a delegate that's
        // already set.
        DraftNotificationRouter.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
