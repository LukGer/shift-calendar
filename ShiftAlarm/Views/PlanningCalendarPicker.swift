import SwiftData
import SwiftUI

/// "New Shifts go into": which editable chosen calendar is the Planning Calendar. Only there to pick from when she
/// has two or more.
struct PlanningCalendarPicker: View {
    let deviceCalendars: [DeviceCalendar]

    @Environment(\.modelContext) private var context
    @Query private var chosenCalendars: [ChosenCalendar]

    var body: some View {
        let editableCalendars = chosenCalendars.editable(among: deviceCalendars)
        if editableCalendars.count >= 2 {
            Section {
                Picker("New Shifts go into", selection: planningCalendar(among: editableCalendars)) {
                    ForEach(editableCalendars) { calendar in
                        Text(calendar.title).tag(calendar.identifier)
                    }
                }
            } footer: {
                Text("Shifts you plan on a day are written into this calendar.")
            }
        }
    }

    private func planningCalendar(among editableCalendars: [ChosenCalendar]) -> Binding<String> {
        Binding {
            chosenCalendars.planningCalendar(among: deviceCalendars)?.identifier ?? ""
        } set: { identifier in
            guard let picked = editableCalendars.first(where: { $0.identifier == identifier }) else { return }
            chosenCalendars.markAsPlanningCalendar(picked)
            try? context.save()
        }
    }
}

#Preview("Two editable chosen calendars") {
    let container = try! ModelContainer(
        for: ChosenCalendar.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    container.mainContext.insert(ChosenCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud"))
    container.mainContext.insert(ChosenCalendar(identifier: "privat", title: "Privat", sourceIdentifier: "icloud"))
    container.mainContext.insert(ChosenCalendar(identifier: "feiertage", title: "Feiertage", sourceIdentifier: "icloud"))
    return Form {
        PlanningCalendarPicker(deviceCalendars: [
            DeviceCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud", isEditable: true),
            DeviceCalendar(identifier: "privat", title: "Privat", sourceIdentifier: "icloud", isEditable: true),
            DeviceCalendar(identifier: "feiertage", title: "Feiertage", sourceIdentifier: "icloud", isEditable: false),
        ])
    }
    .modelContainer(container)
}
