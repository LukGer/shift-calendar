import Foundation
import Observation
import SwiftData

/// The one operation every trigger calls: makes AlarmKit hold exactly the alarms for every Shift in the Arming Window.
@Observable
final class Arming {
    @ObservationIgnored private let openStore: @MainActor () throws -> ModelContainer
    @ObservationIgnored private let calendarReader: CalendarReader
    @ObservationIgnored private let alarmScheduler: AlarmScheduler
    @ObservationIgnored private let notifier: Notifier
    @ObservationIgnored private let clock: WallClock

    init(
        openStore: @escaping @MainActor () throws -> ModelContainer,
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

    /// The latest run's result, for the home screen.
    private(set) var latestResult: ArmingResult?
    @ObservationIgnored private var latestRun: Task<ArmingResult, Never>?

    /// Runs one at a time: a run that starts while another is going waits for it to finish.
    @discardableResult
    func run() async -> ArmingResult {
        let previousRun = latestRun
        let thisRun = Task {
            _ = await previousRun?.value
            let result = await arm()
            latestResult = result
            return result
        }
        latestRun = thisRun
        return await thisRun.value
    }

    private func arm() async -> ArmingResult {
        do {
            let context = try openStore().mainContext
            guard calendarReader.hasFullAccess, !calendarReader.calendars().isEmpty else {
                return .skipped(.calendarNotReadable)
            }
            guard alarmScheduler.isAuthorized else { return .skipped(.alarmsNotAllowed) }
            let now = clock.now
            let calendar = clock.calendar
            let windowEnd = calendar.date(byAdding: .day, value: 7, to: now)!
            let events = calendarReader.events(
                inCalendars: try context.fetch(FetchDescriptor<ChosenCalendar>()).map(\.identifier),
                from: calendar.startOfDay(for: now),
                to: windowEnd
            )
            let shifts = Shift.recognise(
                in: events, of: try context.fetch(FetchDescriptor<ShiftType>()), calendar: calendar)
            let plan = ArmingPlan(shifts: shifts, now: now, windowEnd: windowEnd, calendar: calendar)
            try await armExactly(plan.wantedAlarms)
            await notifier.replaceStaleArmingNotification(firingAt: now.addingTimeInterval(48 * 60 * 60))
            return .armed(plan.shiftsInWindow)
        } catch {
            return .failed
        }
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
}
