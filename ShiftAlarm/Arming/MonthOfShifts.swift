import Foundation

/// A day of the month grid on Home.
struct GridDay: Identifiable {
    let date: Date
    /// False for the leading and trailing days that fill the first and last weeks.
    let isInMonth: Bool
    let isToday: Bool
    let shifts: [GridShift]

    var id: Date { date }
}

/// A Shift as the month grid shows it.
struct GridShift {
    let shiftType: ShiftType
    let isSkipped: Bool
    let isInArmingWindow: Bool
    /// Past, or behind a multi-day or recurring event or one in a calendar she can't edit:
    /// Planning leaves it alone.
    let isLocked: Bool
}

extension CalendarReader {
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
        let events = events(inCalendars: chosenCalendars.map(\.identifier), from: firstDay, to: lastWeek.end)
        let shiftsByDate = Dictionary(
            grouping: Shift.recogniseWithEvents(in: events, of: shiftTypes, calendar: calendar), by: \.shift.date)
        let armingWindow = Arming.armingWindow(at: clock.now, calendar: calendar)
        let editableCalendars = Set(calendars().filter(\.isEditable).map(\.identifier))
        var days: [GridDay] = []
        var date = firstDay
        while date < lastWeek.end {
            days.append(GridDay(
                date: date,
                isInMonth: calendar.isDate(date, equalTo: day, toGranularity: .month),
                isToday: date == armingWindow.lowerBound,
                shifts: (shiftsByDate[date] ?? []).map { shift, events in
                    GridShift(
                        shiftType: shift.shiftType,
                        isSkipped: shift.isSkipped(by: skips),
                        isInArmingWindow: armingWindow.contains(shift.date),
                        isLocked: shift.date < armingWindow.lowerBound || !events.allSatisfy {
                            $0.isPlannable(inEditableCalendars: editableCalendars, calendar: calendar)
                        }
                    )
                }
            ))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }
}

private extension CalendarEvent {
    /// A one-off, single-day event in a calendar she can edit: Planning can delete it cleanly.
    func isPlannable(inEditableCalendars editableCalendars: Set<String>, calendar: Calendar) -> Bool {
        !isRecurring && dates(in: calendar).count == 1 && editableCalendars.contains(calendarIdentifier)
    }
}
