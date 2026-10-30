import SwiftData
import SwiftUI

/// The first-run setup: welcome, the three permissions, her calendars, then naming the Shortcuts found in them.
/// No page needs a permission granted to move on; Settings shows what's still missing.
struct Walkthrough: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query private var shiftTypes: [ShiftType]
    @Query private var chosenCalendars: [ChosenCalendar]
    @State private var page = Page.welcome
    @State private var deviceCalendars: [DeviceCalendar] = []
    @State private var foundShortcuts: [String] = []
    @State private var names: [String: String] = [:]
    private let calendarReader = EventKitReader()

    var body: some View {
        TabView(selection: $page) {
            WalkthroughPage(
                symbol: "alarm.waves.left.and.right",
                title: "Alarms that follow your roster",
                text: "Shift Alarm reads your Shifts from your calendar and sets the right alarms. No more re-setting alarms by hand.",
                button: "Get Started",
                action: showNextPage
            )
            .tag(Page.welcome)

            WalkthroughPage(
                symbol: "calendar",
                title: "Read your calendar",
                text: "Shifts are all-day events titled with a Shortcut like “td” or “nd”. Nothing is ever written to your calendar.",
                button: "Allow Calendar Access",
                action: { ask(calendarReader.requestAccess) }
            )
            .tag(Page.calendarAccess)

            WalkthroughPage(
                symbol: "alarm",
                title: "Ring like the Clock app",
                text: "Alarms ring through silent mode and Focus, even when this app is closed.",
                button: "Allow Alarms",
                action: { ask(AlarmKitScheduler().requestAuthorization) }
            )
            .tag(Page.alarms)

            WalkthroughPage(
                symbol: "bell.badge",
                title: "Hear when alarms go stale",
                text: "If your alarms haven't been updated for two days, a notification tells you before an old alarm makes you late.",
                button: "Allow Notifications",
                action: { ask(UserNotificationsNotifier().requestAuthorization) }
            )
            .tag(Page.notifications)

            WalkthroughPage(
                symbol: "tray.full",
                title: "Where are your Shifts?",
                text: "Choose the calendars your roster is in.",
                button: "Next",
                action: showNextPage
            ) {
                ChosenCalendarToggles(deviceCalendars: deviceCalendars)
            }
            .tag(Page.calendars)

            WalkthroughPage(
                symbol: "textformat.abc",
                title: "Name your Shortcuts",
                text: foundShortcuts.isEmpty
                    ? "Your chosen calendars have no all-day events yet. Add Shift Types later in Settings."
                    : "These all-day titles are in your chosen calendars. Name each one that is a Shift, and leave days off like “U” empty. Set their alarms later in Settings.",
                button: "Done",
                action: finish
            ) {
                Grid(alignment: .leading, verticalSpacing: 12) {
                    ForEach(foundShortcuts, id: \.self) { shortcut in
                        GridRow {
                            Text(shortcut)
                                .monospaced()
                                .bold()
                            TextField("e.g. Tagdienst", text: name(of: shortcut))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .tag(Page.shortcuts)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .task(id: page) {
            deviceCalendars = calendarReader.calendars()
            foundShortcuts = Shift.unmatchedTitles(in: calendarReader.roster(in: chosenCalendars), of: shiftTypes)
        }
    }

    /// Moves on whether she allows it or not.
    private func ask(_ requestPermission: @escaping () async -> Void) {
        Task {
            await requestPermission()
            showNextPage()
        }
    }

    private func showNextPage() {
        withAnimation {
            page = Page(rawValue: page.rawValue + 1)!
        }
    }

    private func name(of shortcut: String) -> Binding<String> {
        Binding { names[shortcut] ?? "" } set: { names[shortcut] = $0 }
    }

    private func finish() {
        try? context.addShiftTypes(for: foundShortcuts, named: names)
        Task { await arming.run() }
        dismiss()
    }

    private enum Page: Int {
        case welcome, calendarAccess, alarms, notifications, calendars, shortcuts
    }
}

private struct WalkthroughPage<Extra: View>: View {
    let symbol: String
    let title: String
    let text: String
    let button: String
    let action: () -> Void
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text(title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(text)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 12) { extra }
                        .padding(.top)
                }
                .padding(32)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .scrollBounceBehavior(.basedOnSize)

            Button(action: action) {
                Text(button)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 56)
    }
}

extension WalkthroughPage where Extra == EmptyView {
    init(symbol: String, title: String, text: String, button: String, action: @escaping () -> Void) {
        self.init(symbol: symbol, title: title, text: text, button: button, action: action) { EmptyView() }
    }
}

#Preview {
    Walkthrough()
        .modelContainer(for: [ShiftType.self, ChosenCalendar.self], inMemory: true)
        .environment(Arming.shared)
}
