import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query(sort: \ShiftType.createdAt) private var shiftTypes: [ShiftType]
    @Query private var chosenCalendars: [ChosenCalendar]
    @State private var deviceCalendars: [DeviceCalendar] = []
    @State private var roster: [CalendarEvent] = []
    private let calendarReader = EventKitReader()

    var body: some View {
        NavigationStack {
            Form {
                Section("Shift Types") {
                    ForEach(shiftTypes) { shiftType in
                        NavigationLink {
                            ShiftTypeEditor(shiftType: shiftType)
                        } label: {
                            LabeledContent {
                                Text(shiftType.alarmSet.summary)
                                    .monospacedDigit()
                            } label: {
                                Text(shiftType.name)
                                Text(shiftType.shortcut)
                                    .monospaced()
                            }
                        }
                    }
                    NavigationLink {
                        ShiftTypeEditor(shiftType: nil)
                    } label: {
                        Label("Add Shift Type", systemImage: "plus")
                    }
                }

                if !notAShiftType.isEmpty {
                    Section {
                        ForEach(notAShiftType, id: \.self) { title in
                            NavigationLink {
                                ShiftTypeEditor(shiftType: nil, newShortcut: title)
                            } label: {
                                LabeledContent {
                                    Text("Add")
                                        .foregroundStyle(.tint)
                                } label: {
                                    Text(title)
                                        .monospaced()
                                }
                            }
                        }
                    } header: {
                        Text("Not a Shift Type")
                    } footer: {
                        Text("These all-day event titles match no Shift Type, so they ring nothing.")
                    }
                }

                Section {
                    ForEach(deviceCalendars) { calendar in
                        Toggle(calendar.title, isOn: isChosen(calendar))
                    }
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Shifts are read from all-day events in these calendars.")
                }

                ArmingStatusSection()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: chosenCalendars.map(\.identifier)) {
                await calendarReader.requestAccess()
                await AlarmKitScheduler().requestAuthorization()
                deviceCalendars = calendarReader.calendars()
                roster = readRoster()
            }
        }
    }

    private var notAShiftType: [String] {
        Shift.unmatchedTitles(in: roster, of: shiftTypes)
    }

    private func readRoster() -> [CalendarEvent] {
        let today = Calendar.current.startOfDay(for: .now)
        let threeMonthsAhead = Calendar.current.date(byAdding: .month, value: 3, to: today)!
        return calendarReader.events(
            inCalendars: chosenCalendars.map(\.identifier), from: today, to: threeMonthsAhead)
    }

    private func isChosen(_ calendar: DeviceCalendar) -> Binding<Bool> {
        Binding {
            chosenCalendars.contains { $0.identifier == calendar.identifier }
        } set: { isOn in
            if isOn {
                context.insert(ChosenCalendar(
                    identifier: calendar.identifier, title: calendar.title,
                    sourceIdentifier: calendar.sourceIdentifier))
            } else {
                chosenCalendars.filter { $0.identifier == calendar.identifier }.forEach(context.delete)
            }
            try? context.save()
            Task { await arming.run() }
        }
    }
}
