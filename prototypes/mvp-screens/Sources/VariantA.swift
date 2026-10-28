// PROTOTYPE variant A, "One list": the 7-day window as one agenda, swipe to skip.
// Everything else lives behind a settings sheet; first run is a paged walkthrough.
import SwiftUI

struct VariantA: View {
    @Environment(Store.self) private var store
    @State private var showsSettings: Bool
    @State private var showsOnboarding: Bool
    private let screen: Screen

    init(screen: Screen) {
        self.screen = screen
        _showsSettings = State(initialValue: screen == .types || screen == .editor)
        _showsOnboarding = State(initialValue: screen == .onboarding)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Armed through \(store.window.last!.dayTitle) · checked 2 min ago", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.window, id: \.self) { date in
                    Section(date.dayTitle) {
                        if let shift = store.shift(on: date) {
                            ShiftRowA(shift: shift)
                        } else {
                            Text("No Shift").foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Upcoming")
            .toolbar { Button("Settings", systemImage: "gearshape") { showsSettings = true } }
            .sheet(isPresented: $showsSettings) { SettingsA(opensEditor: screen == .editor) }
            .fullScreenCover(isPresented: $showsOnboarding) { OnboardingA() }
        }
    }
}

private struct ShiftRowA: View {
    @Environment(Store.self) private var store
    let shift: Shift

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.type.title).font(.headline)
                Text(shift.skipped ? "Skipped" : shift.type.shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(shift.skipped ? .orange : .secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                if shift.type.alarms.isEmpty { Text("No alarms") }
                ForEach(shift.type.alarms) { Text($0.time.clock).monospacedDigit().strikethrough(shift.skipped) }
            }
            .foregroundStyle(shift.skipped || shift.type.alarms.isEmpty ? .secondary : .primary)
        }
        .swipeActions { skipButton.tint(.orange) }
        .contextMenu { skipButton }
    }

    private var skipButton: some View {
        Button(shift.skipped ? "Ring" : "Skip", systemImage: shift.skipped ? "alarm" : "moon.zzz") { store.toggleSkip(shift) }
    }
}

private struct SettingsA: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Int]

    init(opensEditor: Bool) {
        _path = State(initialValue: opensEditor ? [0] : [])
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            Form {
                Section("Shift Types") {
                    ForEach(store.shiftTypes.indices, id: \.self) { index in
                        let type = store.shiftTypes[index]
                        NavigationLink(value: index) {
                            LabeledContent {
                                Text(type.alarmSummary)
                            } label: {
                                Text(type.title)
                                Text(type.shortcut).monospaced()
                            }
                        }
                    }
                    Button("Add Shift Type", systemImage: "plus") { path.append(store.addShiftType()) }
                }
                if !store.unmappedShortcuts.isEmpty {
                    Section {
                        ForEach(store.unmappedShortcuts, id: \.shortcut) { unmapped in
                            LabeledContent {
                                Button("Add") { path.append(store.addShiftType(shortcut: unmapped.shortcut)) }
                            } label: {
                                Text("“\(unmapped.shortcut)”").monospaced()
                                Text("\(unmapped.count) events")
                            }
                        }
                    } header: {
                        Text("Not a Shift Type")
                    } footer: {
                        Text("These all-day event titles match no Shift Type, so they ring nothing.")
                    }
                }
                Section {
                    ForEach($store.calendars) { $calendar in Toggle(calendar.name, isOn: $calendar.chosen) }
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Shifts are read from all-day events in these calendars.")
                }
                Section("Status") {
                    LabeledContent("Calendar access", value: "Allowed")
                    LabeledContent("Alarms", value: "Allowed")
                    LabeledContent("Last armed", value: "2 min ago")
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Int.self) { index in EditorA(type: $store.shiftTypes[index]) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct EditorA: View {
    @Binding var type: ShiftType

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $type.name)
                LabeledContent("Shortcut") {
                    TextField("td", text: $type.shortcut)
                        .multilineTextAlignment(.trailing)
                        .monospaced()
                }
            } footer: {
                Text("All-day events titled “\(type.shortcut)” in your chosen calendars become \(type.title) Shifts.")
            }
            Section {
                ForEach($type.alarms) { $alarm in
                    DatePicker("Alarm", selection: $alarm.time, displayedComponents: .hourAndMinute)
                }
                .onDelete { type.alarms.remove(atOffsets: $0) }
                Button("Add Alarm", systemImage: "plus") { type.alarms.append(Alarm(time: .at(6, 0))) }
            } header: {
                Text("Alarm Set")
            } footer: {
                Text("Rings on the Shift's date. Leave empty to ring nothing.")
            }
        }
        .navigationTitle(type.title.isEmpty ? "New Shift Type" : type.title)
    }
}

private struct OnboardingA: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var page = UserDefaults.standard.integer(forKey: "page")

    var body: some View {
        @Bindable var store = store
        TabView(selection: $page) {
            OnboardingPage(symbol: "alarm.waves.left.and.right", title: "Alarms that follow your roster",
                           text: "Shift Calendar reads your Shifts from your calendar and sets the right alarms. No more re-setting alarms by hand.",
                           button: "Get Started") { page = 1 }
                .tag(0)
            OnboardingPage(symbol: "calendar", title: "Read your calendar",
                           text: "Shifts are all-day events titled with a Shortcut like “td” or “nd”. Nothing is ever written to your calendar.",
                           button: store.calendarAccess ? "Next" : "Allow Calendar Access") {
                if store.calendarAccess { page = 2 } else { store.calendarAccess = true }
            }
            .tag(1)
            OnboardingPage(symbol: "alarm", title: "Ring like the Clock app",
                           text: "Alarms ring through silent mode and Focus, even when this app is closed.",
                           button: store.alarmAccess ? "Next" : "Allow Alarms") {
                if store.alarmAccess { page = 3 } else { store.alarmAccess = true }
            }
            .tag(2)
            OnboardingPage(symbol: "tray.full", title: "Where are your Shifts?",
                           text: "Pick the calendars your roster lives in.", button: "Next") { page = 4 } extra: {
                ForEach($store.calendars) { $calendar in Toggle(calendar.name, isOn: $calendar.chosen) }
            }
            .tag(3)
            OnboardingPage(symbol: "textformat.abc", title: "Name your Shortcuts",
                           text: "These titles appear in \(store.chosenCalendarNames). Set their alarms later in Settings.",
                           button: "Done") { store.onboarded = true; dismiss() } extra: {
                ForEach($store.shiftTypes) { $type in
                    HStack {
                        Text(type.shortcut).monospaced().bold().frame(width: 40, alignment: .leading)
                        TextField("e.g. Tagdienst", text: $type.name).textFieldStyle(.roundedBorder)
                    }
                }
            }
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

private struct OnboardingPage<Extra: View>: View {
    let symbol: String
    let title: String
    let text: String
    let button: String
    let action: () -> Void
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 64)).foregroundStyle(.tint)
            Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(spacing: 12) { extra }.padding(.top)
            Spacer()
            Button(action: action) { Text(button).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .padding(.bottom, 40)
    }
}

extension OnboardingPage where Extra == EmptyView {
    init(symbol: String, title: String, text: String, button: String, action: @escaping () -> Void) {
        self.init(symbol: symbol, title: title, text: text, button: button, action: action) { EmptyView() }
    }
}
