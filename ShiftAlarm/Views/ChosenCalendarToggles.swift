import SwiftData
import SwiftUI

/// A toggle per calendar on the device that chooses it as holding her Shifts. Each change arms straight away.
struct ChosenCalendarToggles: View {
    let deviceCalendars: [DeviceCalendar]

    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query private var chosenCalendars: [ChosenCalendar]

    var body: some View {
        ForEach(deviceCalendars) { calendar in
            Toggle(calendar.title, isOn: isChosen(calendar))
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
