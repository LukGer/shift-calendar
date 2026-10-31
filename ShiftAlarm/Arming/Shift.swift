import Foundation

/// A Shift Type worked on one date.
struct Shift: Hashable {
    let date: Date
    let shiftType: ShiftType

    /// The Shifts in all-day events whose whole title, trimmed and in any case, is a Shortcut:
    /// one per date an event covers, in date order and then in the order the Shift Types were created.
    static func recognise(in events: [CalendarEvent], of shiftTypes: [ShiftType], calendar: Calendar) -> [Shift] {
        recogniseWithEvents(in: events, of: shiftTypes, calendar: calendar).map(\.shift)
    }

    /// The Shifts `recognise` finds, each with every event it is recognised in.
    static func recogniseWithEvents(
        in events: [CalendarEvent], of shiftTypes: [ShiftType], calendar: Calendar
    ) -> [(shift: Shift, events: [CalendarEvent])] {
        var eventsByShift: [Shift: [CalendarEvent]] = [:]
        for (event, shiftType) in match(events, to: shiftTypes) {
            guard let shiftType else { continue }
            for date in event.dates(in: calendar) {
                eventsByShift[Shift(date: date, shiftType: shiftType), default: []].append(event)
            }
        }
        return eventsByShift
            .sorted { ($0.key.date, $0.key.shiftType.createdAt) < ($1.key.date, $1.key.shiftType.createdAt) }
            .map { ($0.key, $0.value) }
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
}

extension CalendarEvent {
    /// The dates the event covers. Works whether it ends at 23:59:59 on its last day (EventKit)
    /// or at the next midnight (ICS).
    func dates(in calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        var date = calendar.startOfDay(for: startDate)
        while date < endDate {
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
