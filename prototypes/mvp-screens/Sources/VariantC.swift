// PROTOTYPE variant C, "Week strip": one scrolling screen, no onboarding wall.
// The week sits on top, the tapped day's detail below it, Shift Types are edited inline,
// and permissions are asked in context by banners.
import SwiftUI

struct VariantC: View {
    @Environment(Store.self) private var store
    @State private var selected = Date.day(1)
    @State private var expanded: ShiftType.ID?
    private let screen: Screen

    init(screen: Screen) {
        self.screen = screen
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !store.calendarAccess {
                            BannerC(symbol: "calendar", title: "See your Shifts",
                                    text: "Allow calendar access to find all-day events like “td” and “nd”. Nothing is written to your calendar.",
                                    button: "Allow Calendar Access") { store.calendarAccess = true }
                        } else if !store.alarmAccess {
                            BannerC(symbol: "alarm", title: "Let your Shifts ring",
                                    text: "Allow alarms so they ring through silent mode and Focus, even when the app is closed.",
                                    button: "Allow Alarms") { store.alarmAccess = true }
                        }
                        if store.calendarAccess {
                            Menu {
                                ForEach($store.calendars) { $calendar in Toggle(calendar.name, isOn: $calendar.chosen) }
                            } label: {
                                Label("Reading \(store.chosenCalendarNames)", systemImage: "calendar")
                                    .font(.subheadline)
                            }
                            WeekStripC(selected: $selected)
                            DayDetailC(date: selected)
                            ShiftTypesC(expanded: $expanded).id("types")
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
                .onAppear {
                    if screen == .editor { expanded = store.shiftTypes.first?.id }
                    if screen == .types || screen == .editor { proxy.scrollTo("types", anchor: .top) }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("This Week")
        }
    }
}

private struct BannerC: View {
    let symbol: String
    let title: String
    let text: String
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
            Button(button, action: action).buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.1), in: .rect(cornerRadius: 20))
    }
}

private struct WeekStripC: View {
    @Environment(Store.self) private var store
    @Binding var selected: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(store.window, id: \.self) { date in
                    let shift = store.shift(on: date)
                    Button { selected = date } label: {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.short))).font(.caption2).foregroundStyle(.secondary)
                            Text(date.formatted(.dateTime.day())).font(.headline)
                            Text(shift?.type.shortcut ?? "–")
                                .font(.caption.monospaced().bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background((shift?.type.color ?? .clear).opacity(0.25), in: .capsule)
                            Text(shift?.type.alarms.first?.time.clock ?? " ")
                                .font(.system(size: 10).monospacedDigit())
                                .strikethrough(shift?.skipped ?? false)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity)
                        .background(date == selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                                    in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            Label("Armed through \(store.window.last!.dayTitle) · checked 2 min ago", systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DayDetailC: View {
    @Environment(Store.self) private var store
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date.dayTitle).font(.caption.bold()).foregroundStyle(.secondary)
            if let shift = store.shift(on: date) {
                Text(shift.type.title).font(.title2.bold())
                if shift.type.alarms.isEmpty { Text("This Shift Type rings nothing.").foregroundStyle(.secondary) }
                ForEach(shift.type.alarms) { alarm in
                    Label(alarm.time.clock, systemImage: "alarm")
                        .font(.title3.monospacedDigit())
                        .strikethrough(shift.skipped)
                        .foregroundStyle(shift.skipped ? .secondary : .primary)
                }
                if !shift.type.alarms.isEmpty {
                    Toggle("Ring for this Shift", isOn: Binding { !shift.skipped } set: { _ in store.toggleSkip(shift) })
                }
            } else {
                Text("No Shift: nothing rings.").font(.title3).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 20))
    }
}

private struct ShiftTypesC: View {
    @Environment(Store.self) private var store
    @Binding var expanded: ShiftType.ID?

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 10) {
            Text("Shift Types").font(.title2.bold())
            ForEach($store.shiftTypes) { $type in
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation { expanded = expanded == type.id ? nil : type.id }
                    } label: {
                        HStack {
                            Text(type.shortcut)
                                .font(.callout.monospaced().bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(type.color.opacity(0.25), in: .capsule)
                            Text(type.title)
                            Spacer()
                            Text(type.alarmSummary).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Image(systemName: expanded == type.id ? "chevron.up" : "chevron.down").foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if expanded == type.id {
                        Divider()
                        LabeledContent("Shortcut") { TextField("td", text: $type.shortcut).monospaced().multilineTextAlignment(.trailing) }
                        LabeledContent("Name") { TextField("Tagdienst", text: $type.name).multilineTextAlignment(.trailing) }
                        Text("Alarms").font(.subheadline.bold()).padding(.top, 4)
                        ForEach($type.alarms) { $alarm in
                            HStack {
                                DatePicker("Alarm", selection: $alarm.time, displayedComponents: .hourAndMinute).labelsHidden()
                                Spacer()
                                Button("Remove", systemImage: "trash") { type.alarms.removeAll { $0.id == alarm.id } }
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.red)
                            }
                        }
                        Button("Add Alarm", systemImage: "plus") { type.alarms.append(Alarm(time: .at(6, 0))) }
                    }
                }
                .padding()
                .background(.background, in: .rect(cornerRadius: 16))
            }
            ForEach(store.unmappedShortcuts, id: \.shortcut) { unmapped in
                HStack {
                    Text("“\(unmapped.shortcut)” ×\(unmapped.count) matches no Shift Type").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("Add") { expanded = store.shiftTypes[store.addShiftType(shortcut: unmapped.shortcut)].id }
                }
                .padding(.horizontal)
            }
        }
    }
}
