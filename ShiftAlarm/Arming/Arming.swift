import Foundation
import Observation
import SwiftData

/// The one operation every trigger calls: makes AlarmKit hold exactly the alarms for every Shift in the Arming Window.
@Observable
final class Arming {
    @ObservationIgnored private let openStore: () throws -> ModelContainer
    @ObservationIgnored private let calendarReader: CalendarReader
    @ObservationIgnored private let alarmScheduler: AlarmScheduler
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private let clock: WallClock

    init(
        openStore: @escaping () throws -> ModelContainer,
        calendarReader: CalendarReader,
        alarmScheduler: AlarmScheduler,
        notifier: Notifier,
        clock: WallClock
    ) {
        self.openStore = openStore
        self.calendarReader = calendarReader
        self.alarmScheduler = alarmScheduler
        self.notifier = notifier
        self.clock = clock
    }

    func run() async {
        do {
            let context = try openStore().mainContext
            let shiftTypes = try context.fetch(FetchDescriptor<ShiftType>())
            let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
            let now = clock.now
            let calendar = clock.calendar
            let windowEnd = calendar.date(byAdding: .day, value: 7, to: now)!
            let events = calendarReader.events(
                inCalendars: chosenCalendars.map(\.identifier),
                from: calendar.startOfDay(for: now),
                to: windowEnd
            )
            var wantedAlarms: [Date: WantedAlarm] = [:]
            for shift in Shift.recognise(in: events, of: shiftTypes, calendar: calendar) {
                for time in shift.shiftType.alarmSet {
                    let instant = calendar.date(
                        bySettingHour: time.hour, minute: time.minute, second: 0, of: shift.date)!
                    guard now < instant, instant <= windowEnd, wantedAlarms[instant] == nil else { continue }
                    wantedAlarms[instant] = WantedAlarm(
                        id: Self.alarmID(for: shift, at: time, calendar: calendar),
                        instant: instant,
                        title: shift.shiftType.name,
                        tint: shift.shiftType.color
                    )
                }
            }
            try await armExactly(Array(wantedAlarms.values))
        } catch {}
    }

    /// Schedules before it cancels, so a run that dies halfway leaves at worst a duplicate, never a gap.
    private func armExactly(_ wantedAlarms: [WantedAlarm]) async throws {
        let armedIDs = try alarmScheduler.alarmIDs()
        for alarm in wantedAlarms.sorted(by: { $0.instant < $1.instant }) where !armedIDs.contains(alarm.id) {
            try await alarmScheduler.schedule(alarm)
        }
        for id in armedIDs.subtracting(wantedAlarms.map(\.id)) {
            try alarmScheduler.cancel(id: id)
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
