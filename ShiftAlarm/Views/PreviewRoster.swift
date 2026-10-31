import SwiftUI

/// A busy roster around today in her Shift Types, for previews: a double Shift tomorrow with one half Skipped,
/// another double Shift, a Skipped Shift inside the Arming Window and one beyond it.
struct PreviewRoster: CalendarStore {
    static let tagdienst = ShiftType(name: "Tagdienst", shortcut: "td", alarmSet: [.init(hour: 5, minute: 0)], colorIndex: 0)
    static let nachtdienst = ShiftType(name: "Nachtdienst", shortcut: "nd", alarmSet: [.init(hour: 18, minute: 30)], colorIndex: 1)
    static let hausrunde = ShiftType(name: "Hausrunde", shortcut: "hrn", alarmSet: [.init(hour: 6, minute: 15)], colorIndex: 2)
    static let ambulanz = ShiftType(name: "Ambulanz", shortcut: "a11", alarmSet: [.init(hour: 9, minute: 0)], colorIndex: 3)
    static let spät = ShiftType(name: "Spät", shortcut: "e6", alarmSet: [], colorIndex: 4)

    private static let shortcutsByDayFromToday: [Int: [String]] = [
        -9: ["td"], -8: ["td"], -7: ["nd"], -6: ["nd"], -3: ["hrn"], -1: ["td"],
        0: ["td"], 1: ["td", "hrn"], 2: ["nd"], 3: ["nd"], 6: ["a11"], 7: ["e6"], 8: ["e6"],
        9: ["td"], 11: ["nd"], 12: ["nd"], 14: ["hrn"], 15: ["td"], 16: ["td", "a11"], 17: ["a11"], 20: ["td"],
    ]

    let clock: WallClock
    let hasFullAccess = true

    func calendars() -> [DeviceCalendar] {
        [DeviceCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud", isEditable: true)]
    }

    func events(inCalendars identifiers: [String], from start: Date, to end: Date) -> [CalendarEvent] {
        Self.shortcutsByDayFromToday.flatMap { days, shortcuts in
            shortcuts.map { shortcut in
                let date = day(days)
                return CalendarEvent(
                    identifier: "\(days)\(shortcut)", calendarIdentifier: "dienste", isRecurring: false,
                    title: shortcut, startDate: date, endDate: date.addingTimeInterval(24 * 60 * 60 - 1),
                    isAllDay: true)
            }
        }
    }

    /// The month containing today.
    var busyMonth: [GridDay] {
        monthOfShifts(
            containing: clock.now,
            in: [ChosenCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud")],
            of: [Self.tagdienst, Self.nachtdienst, Self.hausrunde, Self.ambulanz, Self.spät],
            skips: [
                Skip(date: day(1), shiftTypeID: Self.hausrunde.id),
                Skip(date: day(3), shiftTypeID: Self.nachtdienst.id),
                Skip(date: day(14), shiftTypeID: Self.hausrunde.id),
            ],
            clock: clock)
    }

    private func day(_ daysFromToday: Int) -> Date {
        let calendar = clock.calendar
        return calendar.date(byAdding: .day, value: daysFromToday, to: calendar.startOfDay(for: clock.now))!
    }
}

extension WindowShift {
    static func preview(
        inDays days: Int, _ shiftType: ShiftType, alarmTimes: [String], isSkipped: Bool = false
    ) -> WindowShift {
        let calendar = Calendar.current
        return WindowShift(
            date: calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now))!,
            shiftTypeID: shiftType.id,
            name: shiftType.name,
            color: shiftType.color,
            alarmTimes: alarmTimes.map { text in
                let parts = text.split(separator: ":").compactMap { Int($0) }
                return AlarmTime(hour: parts[0], minute: parts[1])
            },
            isSkipped: isSkipped
        )
    }
}
