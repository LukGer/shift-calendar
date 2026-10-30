import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
                    ChosenCalendarToggles(deviceCalendars: deviceCalendars)
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
                await UserNotificationsNotifier().requestAuthorization()
                deviceCalendars = calendarReader.calendars()
                roster = calendarReader.roster(in: chosenCalendars)
            }
        }
    }

    private var notAShiftType: [String] {
        Shift.unmatchedTitles(in: roster, of: shiftTypes)
    }
}
