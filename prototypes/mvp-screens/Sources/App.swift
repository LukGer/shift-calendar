// PROTOTYPE for the wayfinder ticket "What do the MVP screens look like?".
// Three structurally different MVP layouts on one app, switchable from the floating bar
// or at launch with `-variant A|B|C -screen onboarding|home|types|editor`.
import SwiftUI

@main
struct PrototypeApp: App {
    var body: some Scene {
        WindowGroup { VariantSwitcher() }
    }
}

private let variants = [("A", "One list"), ("B", "Tabs"), ("C", "Week strip")]

struct VariantSwitcher: View {
    @AppStorage("variant") private var variant = "A"
    private let screen = Screen(rawValue: UserDefaults.standard.string(forKey: "screen") ?? "") ?? .home
    private let showsBar = !UserDefaults.standard.bool(forKey: "hideSwitcher")

    var body: some View {
        VariantHost(variant: variant, screen: screen)
            .id(variant)
            .overlay(alignment: .bottom) {
                if showsBar { bar }
            }
    }

    private var bar: some View {
        let index = variants.firstIndex { $0.0 == variant } ?? 0
        return HStack(spacing: 16) {
            Button { cycle(index - 1) } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Text("\(variants[index].0) · \(variants[index].1)").monospaced()
            Button { cycle(index + 1) } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .font(.footnote.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black, in: .capsule)
        .padding(.bottom, 90)
    }

    private func cycle(_ index: Int) {
        variant = variants[(index + variants.count) % variants.count].0
    }
}

private struct VariantHost: View {
    let variant: String
    let screen: Screen
    @State private var store: Store

    init(variant: String, screen: Screen) {
        self.variant = variant
        self.screen = screen
        _store = State(initialValue: Store(screen: screen))
    }

    var body: some View {
        Group {
            switch variant {
            case "B": VariantB(screen: screen)
            case "C": VariantC(screen: screen)
            default: VariantA(screen: screen)
            }
        }
        .environment(store)
    }
}
