import EventKit

/// Reads her calendars through EventKit. Each call uses a fresh event store, so it sees access granted since the last call.
struct EventKitReader: CalendarReader {
    /// Asks for full calendar access the first time; afterwards returns without asking.
    func requestAccess() async {
        _ = try? await EKEventStore().requestFullAccessToEvents()
    }

    func calendars() -> [DeviceCalendar] {
        EKEventStore().calendars(for: .event).map {
            DeviceCalendar(identifier: $0.calendarIdentifier, title: $0.title, sourceIdentifier: $0.source.sourceIdentifier)
        }
    }

    func events(inCalendars identifiers: [String], from start: Date, to end: Date) -> [CalendarEvent] {
        let store = EKEventStore()
        let calendars = identifiers.compactMap(store.calendar(withIdentifier:))
        guard !calendars.isEmpty else { return [] }  // EventKit searches every calendar when given none
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).map {
            CalendarEvent(title: $0.title ?? "", startDate: $0.startDate, endDate: $0.endDate, isAllDay: $0.isAllDay)
        }
    }
}

struct DeviceCalendar: Identifiable {
    let identifier: String
    let title: String
    let sourceIdentifier: String

    var id: String { identifier }
}
