//
//  OnboardingView.swift
//  Hazel
//

import SwiftUI
import UserNotifications

/// First-launch wizard shown instead of auto-opening Settings — walks a new
/// user through connecting accounts, notifications, and importing templates.
/// Presented as a `.sheet` from `ContentView` with interactive dismissal
/// disabled — the wizard only closes via the last page's Done button, since
/// swiping it away wouldn't otherwise leave a visible way back in; regular
/// Settings is unaffected.
///
/// The logo, header title, and description sit outside the paging scroll
/// view so only the interactive content underneath moves between pages —
/// the header instead crossfades via `.id(page)` + `.transition(.opacity)`.
///
/// Paging uses a `ScrollView` + `.scrollTargetBehavior(.paging)` rather than
/// `TabView(.page)`: a `TabView`'s selection can be changed programmatically,
/// but doing so just swaps content in place instead of sliding — tapping
/// Continue needs the same slide motion a swipe produces, which only a
/// scroll-position-driven pager gives you when the change is wrapped in
/// `withAnimation`.
///
/// The bottom button doubles as each page's primary action (not just
/// "Continue") — it enables notifications on that page, and finishes on the
/// last. Swiping past a page without tapping it is always still allowed;
/// only the button itself is ever disabled (welcome, until an account is
/// connected).
struct OnboardingView: View {
    @State private var ynabAuth = YNABAuthService()
    @State private var splitwiseAuth = SplitwiseAuthService()
    @State private var scrollPosition: OnboardingPage? = .welcome
    @State private var usesLegacyShortcut: Bool?
    @State private var migration = LegacyMigrationCallbackHandler()
    @Environment(\.dismiss) private var dismiss

    private var page: OnboardingPage { scrollPosition ?? .welcome }

    private var isContinueDisabled: Bool {
        switch page {
        case .welcome:
            return !ynabAuth.isAuthenticated && !splitwiseAuth.isAuthenticated
        case .notifications:
            return false
        case .importTemplate:
            return usesLegacyShortcut == nil
        }
    }

    // Still tappable (Done just dismisses either way) but visually
    // de-emphasized until the user either declines the shortcut or actually
    // runs the migration — otherwise it's too easy to tap Done having only
    // installed the shortcut without running it.
    private var isContinueDeemphasized: Bool {
        page == .importTemplate && usesLegacyShortcut == true && migration.resultMessage == nil
    }

    private var continueTitle: String {
        switch page {
        case .welcome: return "Continue"
        case .notifications: return "Enable Notifications"
        case .importTemplate: return "Done"
        }
    }

    private enum OnboardingPage: Int, CaseIterable, Hashable, Sendable {
        case welcome
        case notifications
        case importTemplate

        var title: String {
            switch self {
            case .welcome: return "Welcome to Hazel"
            case .notifications: return "Enable Reminders"
            case .importTemplate: return "Migrate Data"
            }
        }

        var description: LocalizedStringKey {
            switch self {
            case .welcome:
                return "Connect YNAB and/or Splitwise to get started — Hazel isn't much use without at least one."
            case .notifications:
                return "Reminds you about an incomplete wallet transaction or offline transactions that are waiting to sync. Nothing else."
            case .importTemplate:
                return "Using the \"YNAB Toolkit Shortcut\"? Install the \"Transaction → YNAB Shortcut\" below, then tap Run Migration to migrate your automation data to Hazel."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 180)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .opacity(0.8)

            ZStack {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .id(page)
                    .transition(.opacity)
            }
            .frame(height: 34)
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.top, 12)

            // All three descriptions stay mounted at once (crossfading via
            // opacity) instead of swapping a single Text via .id — that way
            // the ZStack's height is always the tallest of the three, so it
            // never needs a fixed height yet still doesn't jump between
            // pages of different description lengths.
            ZStack(alignment: .top) {
                ForEach(OnboardingPage.allCases, id: \.self) { candidate in
                    Text(candidate.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 25)
                        .opacity(candidate == page ? 1 : 0)
                        .accessibilityHidden(candidate != page)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.top, 10)

            // Fills all the remaining space between the header and the
            // dots/button below — this container's own size never depends
            // on which page is showing (each page fills whatever height
            // it's given), so swiping between pages of different content
            // heights doesn't move the dots/button at all.
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    OnboardingWelcomePage(ynabAuth: ynabAuth, splitwiseAuth: splitwiseAuth)
                        .containerRelativeFrame(.horizontal)
                        .id(OnboardingPage.welcome)

                    OnboardingNotificationsPage()
                        .containerRelativeFrame(.horizontal)
                        .id(OnboardingPage.notifications)

                    OnboardingImportPage(usesLegacyShortcut: $usesLegacyShortcut, migration: migration)
                        .containerRelativeFrame(.horizontal)
                        .id(OnboardingPage.importTemplate)
                }
                .scrollTargetLayout()
            }
            .frame(maxHeight: .infinity)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollIndicators(.hidden)

            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.self) { candidate in
                    Circle()
                        .fill(candidate == page ? Color.secondary : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.bottom, 16)

            Button {
                switch page {
                case .welcome:
                    withAnimation { scrollPosition = .notifications }
                case .notifications:
                    NotificationsPreferenceStore.isEnabled = true
                    requestNotificationPermission()
                    withAnimation { scrollPosition = .importTemplate }
                case .importTemplate:
                    dismiss()
                }
            } label: {
                Text(continueTitle)
                    .frame(maxWidth: .infinity)
            }
            .disabled(isContinueDisabled)
            .tint(isContinueDeemphasized ? Color.secondary : Color.accentColor)
            .animation(.easeInOut(duration: 0.2), value: isContinueDeemphasized)
            .padding(.horizontal, 30)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
        }
        .background(Color.sheetBackgroundColor)
        .sensoryFeedback(.selection, trigger: page)
    }

    // Requesting more than once is a no-op once the user has already
    // answered the system prompt, matching SettingsView's toggle behavior.
    private func requestNotificationPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
}

#Preview {
    OnboardingView()
}
