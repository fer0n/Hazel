//
//  StatusBarBackground.swift
//  Relay
//

import SwiftUI

private struct StatusBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .top) {
                Color.black.opacity(0.0000001).frame(width: 1, height: 1)
            }
    }
}

extension View {
    func statusBarBackground() -> some View {
        modifier(StatusBarBackground())
    }
}
