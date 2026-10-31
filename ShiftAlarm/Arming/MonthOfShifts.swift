import Foundation

/// A day of the month grid on Home.
struct GridDay: Identifiable {
    let date: Date
    /// False for the leading and trailing days that fill the first and last weeks.
    let isInMonth: Bool
    let isToday: Bool
    /// Before today: the day sheet opens read-only.
    let isPast: Bool
    let shifts: [GridShift]

    var id: Date { date }
}

/// A Shift as the month grid shows it.
struct GridShift {
    let shiftType: ShiftType
    let isSkipped: Bool
    let hasAlarmArmed: Bool
    /// Past, or behind a multi-day or recurring event or one in a calendar she can't edit:
    /// Planning leaves it alone.
    let isLocked: Bool
}

extension CalendarStore {
    /// Every day of the weeks the month containing `day` touches, starting on the locale's first weekday,
    /// with the Shifts on it.
    func monthOfShifts(
        containing day: Date, in chosenCalendars: [ChosenCalendar], of shiftTypes: [ShiftType], skips: [Skip],
        clock: WallClock
    ) -> [GridDay] {
        let calendar = clock.calendar
        let month = calendar.dateInterval(of: .month, for: day)!
        let firstDay = calendar.dateInterval(of: .weekOfYear, for: month.start)!.start
        let lastWeek = calendar.dateInterval(of: .weekOfYear, for: month.end.addingTimeInterval(-1))!
        let shiftsByDate = Dictionary(
            grouping: shiftsInCalendar(
                in: chosenCalendars, of: shiftTypes, from: firstDay, to: lastWeek.end, clock: clock),
            by: \.shift.date)
        let armingWindow = Arming.armingWindow(at: clock.now, calendar: calendar)
        var days: [GridDay] = []
        var date = firstDay
        while date < lastWeek.end {
            days.append(GridDay(
                date: date,
                isInMonth: calendar.isDate(date, equalTo: day, toGranularity: .month),
                isToday: date == armingWindow.lowerBound,
                isPast: date < armingWindow.lowerBound,
                shifts: (shiftsByDate[date] ?? []).map { shiftInCalendar in
                    let shift = shiftInCalendar.shift
                    let isSkipped = shift.isSkipped(by: skips)
                    return GridShift(
                        shiftType: shift.shiftType,
                        isSkipped: isSkipped,
                        hasAlarmArmed: !isSkipped && !shift.alarmInstants(
                            after: clock.now, through: armingWindow.upperBound, calendar: calendar
                        ).isEmpty,
                        isLocked: shiftInCalendar.isLocked
                    )
                }
            ))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }

    /// The Shifts in her chosen calendars from `start` until `end`.
    func shiftsInCalendar(
        in chosenCalendars: [ChosenCalendar], of shiftTypes: [ShiftType], from start: Date, to end: Date,
        clock: WallClock
    ) -> [ShiftInCalendar] {
        let calendar = clock.calendar
        let today = calendar.startOfDay(for: clock.now)
        let editableCalendars = Set(calendars().filter(\.isEditable).map(\.identifier))
        let events = events(inCalendars: chosenCalendars.map(\.identifier), from: start, to: end)
        return Shift.recogniseWithEvents(in: events, of: shiftTypes, calendar: calendar).map { shift, events in
            let isLocked = shift.date < today || !events.allSatisfy {
                $0.isPlannable(inEditableCalendars: editableCalendars, calendar: calendar)
            }
            return ShiftInCalendar(shift: shift, events: events, isLocked: isLocked)
        }
    }
}

/// A Shift with the events it is recognised in.
struct ShiftInCalendar {
    let shift: Shift
    let events: [CalendarEvent]
    /// Past, or behind an event Planning can't delete cleanly.
    let isLocked: Bool
}

private extension CalendarEvent {
    /// A one-off, single-day event in a calendar she can edit: Planning can delete it cleanly.
    func isPlannable(inEditableCalendars editableCalendars: Set<String>, calendar: Calendar) -> Bool {
        !isRecurring && dates(in: calendar).count == 1 && editableCalendars.contains(calendarIdentifier)
    }
}
