// PROTOTYPE variant B, "Tabs": the next Shift is the hero; Shift Types and settings get their own tabs.
// First run is one checklist screen; Shortcuts are mapped later from cards in the Shift Types tab.
import SwiftUI

private enum TabB { case next, types, settings }

struct VariantB: View {
    @State private var tab: TabB
    @State private var showsOnboarding: Bool
    private let screen: Screen

    init(screen: Screen) {
        self.screen = screen
        _tab = State(initialValue: screen == .types || screen == .editor ? .types : .next)
        _showsOnboarding = State(initialValue: screen == .onboarding)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Next", systemImage: "alarm", value: .next) { NextB() }
            Tab("Shift Types", systemImage: "square.grid.2x2", value: .types) { TypesB(editing: screen == .editor ? 0 : nil) }
            Tab("Settings", systemImage: "gearshape", value: .settings) { SettingsB() }
        }
        .fullScreenCover(isPresented: $showsOnboarding) { OnboardingB() }
    }
}

struct NextB: View {
    @Environment(Store.self) private var store
    var openSettings: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let next = store.shifts.first { HeroB(shift: next) }
                    Text("Later this week").font(.headline).padding(.top)
                    VStack(spacing: 0) {
                        ForEach(store.shifts.dropFirst()) { shift in
                            CompactRowB(shift: shift)
                            Divider()
                        }
                    }
                    .background(.background, in: .rect(cornerRadius: 16))
                    Text("Days without a Shift ring nothing.").font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Next Shift")
            .toolbar {
                if let openSettings { Button("Settings", systemImage: "gearshape", action: openSettings) }
            }
        }
    }
}

private struct HeroB: View {
    @Environment(Store.self) private var store
    let shift: Shift

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shift.date.dayTitle.uppercased()).font(.caption.bold()).opacity(0.8)
            Text(shift.type.title).font(.largeTitle.bold())
            if let first = shift.type.alarms.first {
                Text(first.time.clock)
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .strikethrough(shift.skipped)
            }
            if shift.type.alarms.count > 1 {
                Text("then " + shift.type.alarms.dropFirst().map(\.time.clock).joined(separator: " · ")).monospacedDigit()
            }
            Button(shift.skipped ? "Ring for this Shift" : "Skip this Shift", systemImage: "moon.zzz") { store.toggleSkip(shift) }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shift.type.color.gradient, in: .rect(cornerRadius: 24))
    }
}

private struct CompactRowB: View {
    @Environment(Store.self) private var store
    let shift: Shift

    var body: some View {
        HStack {
            Text(shift.date.formatted(.dateTime.weekday(.abbreviated).day()))
                .frame(width: 64, alignment: .leading)
                .foregroundStyle(.secondary)
            Circle().fill(shift.type.color).frame(width: 10)
            Text(shift.type.title)
            Spacer()
            Text(shift.skipped ? "Skipped" : shift.type.alarmSummary)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(shift.skipped ? .orange : .secondary)
            Menu {
                Button(shift.skipped ? "Ring for this Shift" : "Skip this Shift") { store.toggleSkip(shift) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding()
    }
}

private struct TypesB: View {
    @Environment(Store.self) private var store
    @State private var editing: Int?

    init(editing: Int?) {
        _editing = State(initialValue: editing)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 12) {
                    ForEach(store.shiftTypes.indices, id: \.self) { index in
                        Button { editing = index } label: { TypeCardB(type: store.shiftTypes[index]) }
                            .buttonStyle(.plain)
                    }
                    Button { editing = store.addShiftType() } label: {
                        Label("New Shift Type", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                    }
                }
                ForEach(store.unmappedShortcuts, id: \.shortcut) { unmapped in
                    HStack {
                        Image(systemName: "questionmark.circle.fill").foregroundStyle(.yellow).font(.title2)
                        Text("“\(unmapped.shortcut)” appears \(unmapped.count)× in \(store.chosenCalendarNames) but is no Shift Type.")
                            .font(.subheadline)
                        Button("Add") { editing = store.addShiftType(shortcut: unmapped.shortcut) }.buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.yellow.opacity(0.12), in: .rect(cornerRadius: 16))
                    .padding(.top)
                }
            }
            .padding()
            .navigationTitle("Shift Types")
            .sheet(isPresented: Binding { editing != nil } set: { if !$0 { editing = nil } }) {
                if let editing { EditorB(type: $store.shiftTypes[editing]) }
            }
        }
    }
}

private struct TypeCardB: View {
    let type: ShiftType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(type.shortcut).font(.system(.largeTitle, design: .monospaced).bold()).foregroundStyle(type.color)
            Text(type.title).font(.headline)
            Text(type.alarmSummary).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(type.color.opacity(0.12), in: .rect(cornerRadius: 20))
    }
}

private struct EditorB: View {
    @Binding var type: ShiftType
    @Environment(\.dismiss) private var dismiss
    @State private var newTime = Date.at(6, 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        TextField("td", text: $type.shortcut)
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(type.color)
                        TextField("Name, e.g. Tagdienst", text: $type.name).font(.title3).multilineTextAlignment(.center)
                        Text("Matches all-day events titled exactly “\(type.shortcut)”, ignoring case.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alarm Set").font(.headline)
                        if type.alarms.isEmpty { Text("No alarms: this Shift Type rings nothing.").foregroundStyle(.secondary) }
                        ForEach(type.alarms) { alarm in
                            HStack {
                                Text(alarm.time.clock).font(.title2.monospacedDigit())
                                Spacer()
                                Button("Remove", systemImage: "minus.circle.fill") { type.alarms.removeAll { $0.id == alarm.id } }
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .background(.background.secondary, in: .rect(cornerRadius: 14))
                        }
                    }
                    VStack {
                        DatePicker("New alarm", selection: $newTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                        Button("Add \(newTime.clock)", systemImage: "plus") {
                            type.alarms.append(Alarm(time: newTime))
                            type.alarms.sort { $0.time < $1.time }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct SettingsB: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Armed through", value: store.window.last!.dayTitle)
                    LabeledContent("Last checked", value: "2 min ago")
                } header: {
                    Text("Arming")
                } footer: {
                    Text("Alarms are re-armed in the background each time one rings.")
                }
                Section("Calendars") {
                    ForEach($store.calendars) { $calendar in Toggle(calendar.name, isOn: $calendar.chosen) }
                }
                Section("Permissions") {
                    LabeledContent("Calendar", value: store.calendarAccess ? "Allowed" : "Not allowed")
                    LabeledContent("Alarms", value: store.alarmAccess ? "Allowed" : "Not allowed")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct OnboardingB: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    StepB(number: 1, title: "Calendar access", detail: "To read your Shifts", done: store.calendarAccess) {
                        Button("Allow") { store.calendarAccess = true }
                    }
                    StepB(number: 2, title: "Alarms", detail: "To ring through silent and Focus", done: store.alarmAccess) {
                        Button("Allow") { store.alarmAccess = true }
                    }
                    StepB(number: 3, title: "Shift calendar", detail: store.calendars.contains(where: \.chosen) ? store.chosenCalendarNames : "Where your roster lives",
                          done: store.calendars.contains(where: \.chosen)) {
                        Menu("Choose") {
                            ForEach($store.calendars) { $calendar in Toggle(calendar.name, isOn: $calendar.chosen) }
                        }
                    }
                } footer: {
                    Text("Next you'll set up your Shift Types. You can change all of this later in Settings.")
                }
            }
            .navigationTitle("Set Up")
            .safeAreaInset(edge: .bottom) {
                Button { store.onboarded = true; dismiss() } label: { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.calendarAccess || !store.alarmAccess || !store.calendars.contains(where: \.chosen))
                    .padding()
            }
        }
    }
}

private struct StepB<Action: View>: View {
    let number: Int
    let title: String
    let detail: String
    let done: Bool
    @ViewBuilder let action: Action

    var body: some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if !done { action.buttonStyle(.bordered) }
        }
    }
}
