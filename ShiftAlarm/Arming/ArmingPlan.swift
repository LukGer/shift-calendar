import Foundation

/// Which alarms the Shifts in the Arming Window want, and what the home screen shows for them.
struct ArmingPlan {
    private(set) var shiftsInWindow: [WindowShift] = []
    private(set) var wantedAlarms: [WantedAlarm] = []

    /// Each alarm time becomes an instant on the Shift's own date. Instants that have passed or lie beyond
    /// the window are dropped, and identical instants merge into the alarm of the Shift that comes first.
    /// A skipped Shift wants no alarms. Shifts before today are left out.
    init(shifts: [Shift], skips: [Skip], now: Date, windowEnd: Date, calendar: Calendar) {
        let window = calendar.startOfDay(for: now)...windowEnd
        var wantedInstants: Set<Date> = []
        for shift in shifts {
            let shiftType = shift.shiftType
            let isSkipped = shift.isSkipped(by: skips)
            var alarmTimes: [AlarmTime] = []
            for (time, instant) in shift.alarmInstants(after: now, through: windowEnd, calendar: calendar) {
                alarmTimes.append(time)
                if !isSkipped, wantedInstants.insert(instant).inserted {
                    wantedAlarms.append(WantedAlarm(
                        id: Self.alarmID(for: shift, at: time, calendar: calendar),
                        instant: instant,
                        title: shiftType.name,
                        tint: shiftType.color
                    ))
                }
            }
            if !alarmTimes.isEmpty || (shiftType.alarmSet.isEmpty && window.contains(shift.date)) {
                shiftsInWindow.append(WindowShift(
                    date: shift.date, shiftTypeID: shiftType.id, name: shiftType.name,
                    color: shiftType.color, alarmTimes: alarmTimes, isSkipped: isSkipped))
            }
        }
    }

    private static let alarmIDNamespace = UUID(uuidString: "AF661BC3-756B-422B-A25D-214AE9848CDC")!

    /// Changing the Shift's date, its Shift Type or the alarm time gives a new ID, so an armed ID never needs rescheduling.
    private static func alarmID(for shift: Shift, at time: AlarmTime, calendar: Calendar) -> UUID {
        let day = calendar.dateComponents([.year, .month, .day], from: shift.date)
        let date = String(format: "%04d-%02d-%02d", day.year!, day.month!, day.day!)
        return UUID(name: "\(date)|\(shift.shiftType.id.uuidString)|\(time.text)", namespace: alarmIDNamespace)
    }
}

extension Shift {
    func alarmInstants(after now: Date, through windowEnd: Date, calendar: Calendar) -> [(time: AlarmTime, instant: Date)] {
        shiftType.alarmSet
            .map { ($0, $0.instant(on: date, calendar: calendar)) }
            .filter { now < $0.instant && $0.instant <= windowEnd }
    }
}
