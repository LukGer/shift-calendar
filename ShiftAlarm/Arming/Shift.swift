import Foundation

/// A Shift Type worked on one date.
struct Shift: Hashable {
    let date: Date
    let shiftType: ShiftType

    /// The Shifts in all-day events whose whole title, trimmed and in any case, is a Shortcut:
    /// one per date an event covers, in date order and then in the order the Shift Types were created.
    static func recognise(in events: [CalendarEvent], of shiftTypes: [ShiftType], calendar: Calendar) -> [Shift] {
        let shiftTypesByShortcut = Dictionary(
            shiftTypes.map { (ShiftType.comparable($0.shortcut), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var shifts: Set<Shift> = []
        for event in events where event.isAllDay {
            guard let shiftType = shiftTypesByShortcut[ShiftType.comparable(event.title)] else { continue }
            for date in dates(coveredBy: event, calendar: calendar) {
                shifts.insert(Shift(date: date, shiftType: shiftType))
            }
        }
        return shifts.sorted { ($0.date, $0.shiftType.createdAt) < ($1.date, $1.shiftType.createdAt) }
    }

    /// Works whether the event ends at 23:59:59 on its last day (EventKit) or at the next midnight (ICS).
    private static func dates(coveredBy event: CalendarEvent, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var date = calendar.startOfDay(for: event.startDate)
        while date < event.endDate {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }
}

extension ShiftType {
    /// How a Shortcut is compared: trimmed and ignoring case.
    static func comparable(_ shortcut: String) -> String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
