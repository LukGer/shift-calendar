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
                        id: UUID(), instant: instant, title: shift.shiftType.name, tint: shift.shiftType.color)
                }
            }
            for alarm in wantedAlarms.values {
                try await alarmScheduler.schedule(alarm)
            }
        } catch {}
    }
}
