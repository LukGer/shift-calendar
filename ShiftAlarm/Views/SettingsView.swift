import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query(sort: \ShiftType.createdAt) private var shiftTypes: [ShiftType]
    @Query private var chosenCalendars: [ChosenCalendar]
    @State private var deviceCalendars: [DeviceCalendar] = []
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

                Section {
                    ForEach(deviceCalendars) { calendar in
                        Toggle(calendar.title, isOn: isChosen(calendar))
                    }
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Shifts are read from all-day events in these calendars.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await calendarReader.requestAccess()
                deviceCalendars = calendarReader.calendars()
            }
        }
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
