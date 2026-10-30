import Foundation

/// A Shift Type worked on one date.
struct Shift: Hashable {
    let date: Date
    let shiftType: ShiftType

    /// The Shifts in all-day events whose whole title, trimmed and in any case, is a Shortcut:
    /// one per date an event covers, in date order and then in the order the Shift Types were created.
    static func recognise(in events: [CalendarEvent], of shiftTypes: [ShiftType], calendar: Calendar) -> [Shift] {
        var shifts: Set<Shift> = []
        for (event, shiftType) in match(events, to: shiftTypes) {
            guard let shiftType else { continue }
            for date in dates(coveredBy: event, calendar: calendar) {
                shifts.insert(Shift(date: date, shiftType: shiftType))
            }
        }
        return shifts.sorted { ($0.date, $0.shiftType.createdAt) < ($1.date, $1.shiftType.createdAt) }
    }

    /// The titles of all-day events that are no Shift Type's Shortcut, trimmed, each once whatever its case,
    /// in alphabetical order.
    static func unmatchedTitles(in events: [CalendarEvent], of shiftTypes: [ShiftType]) -> [String] {
        var titlesByShortcut: [String: String] = [:]
        for (event, shiftType) in match(events, to: shiftTypes) where shiftType == nil {
            let shortcut = event.title.trimmedAndLowercased
            guard !shortcut.isEmpty, titlesByShortcut[shortcut] == nil else { continue }
            titlesByShortcut[shortcut] = event.title.trimmed
        }
        return titlesByShortcut.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Each all-day event, with the Shift Type whose Shortcut is its title, or nil when there is none.
    private static func match(
        _ events: [CalendarEvent], to shiftTypes: [ShiftType]
    ) -> [(event: CalendarEvent, shiftType: ShiftType?)] {
        let shiftTypesByShortcut = Dictionary(
            shiftTypes.map { ($0.shortcut.trimmedAndLowercased, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return events.filter(\.isAllDay).map { ($0, shiftTypesByShortcut[$0.title.trimmedAndLowercased]) }
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

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAndLowercased: String {
        trimmed.lowercased()
    }
}
