// PROTOTYPE variant D, the verdict: B's home (next-Shift hero, compact rest of week) with
// everything else from A (settings sheet behind the gear, Form editor, paged walkthrough). No tab bar.
import SwiftUI

struct VariantD: View {
    @State private var showsSettings: Bool
    @State private var showsOnboarding: Bool
    private let screen: Screen

    init(screen: Screen) {
        self.screen = screen
        _showsSettings = State(initialValue: screen == .types || screen == .editor)
        _showsOnboarding = State(initialValue: screen == .onboarding)
    }

    var body: some View {
        NextB { showsSettings = true }
            .sheet(isPresented: $showsSettings) { SettingsA(opensEditor: screen == .editor) }
            .fullScreenCover(isPresented: $showsOnboarding) { OnboardingA() }
    }
}
