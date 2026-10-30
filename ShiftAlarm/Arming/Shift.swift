import Foundation

/// A Shift Type worked on one date.
struct Shift: Hashable {
    let date: Date
    let shiftType: ShiftType

    /// The Shifts in all-day events whose whole title, trimmed and in any case, is a Shortcut.
    static func recognise(in events: [CalendarEvent], of shiftTypes: [ShiftType], calendar: Calendar) -> [Shift] {
        let shiftTypesByShortcut = Dictionary(
            shiftTypes.map { (ShiftType.comparable($0.shortcut), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var shifts: [Shift] = []
        for event in events where event.isAllDay {
            guard let shiftType = shiftTypesByShortcut[ShiftType.comparable(event.title)] else { continue }
            shifts.append(Shift(date: calendar.startOfDay(for: event.startDate), shiftType: shiftType))
        }
        return shifts
    }
}

extension ShiftType {
    /// How a Shortcut is compared: trimmed and ignoring case.
    static func comparable(_ shortcut: String) -> String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
