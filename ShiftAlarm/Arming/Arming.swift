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
            BackgroundRefresh.schedule()
            return result
        }
        latestRun = thisRun
        return await thisRun.value
    }

    private func arm() async -> ArmingResult {
        guard let context = try? openStore().mainContext else { return .failed }
        let now = clock.now
        let result: ArmingResult
        do {
            result = try await arm(in: context, now: now)
        } catch {
            result = .failed
        }
        record(result, at: now, in: context)
        return result
    }

    /// Changes no alarm unless it can see her calendars and is allowed to schedule alarms.
    private func arm(in context: ModelContext, now: Date) async throws -> ArmingResult {
        let calendar = clock.calendar
        try pruneSkips(before: calendar.startOfDay(for: now), in: context)
        let deviceCalendars = calendarReader.calendars()
        guard calendarReader.hasFullAccess, !deviceCalendars.isEmpty else { return .skipped(.calendarNotReadable) }
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        guard chosenCalendars.allSatisfy({ $0.isFound(among: deviceCalendars) }) else {
            return .skipped(.chosenCalendarMissing)
        }
        guard alarmScheduler.isAuthorized else { return .skipped(.alarmsNotAllowed) }
        let windowEnd = calendar.date(byAdding: .day, value: 7, to: now)!
        let events = calendarReader.events(
            inCalendars: chosenCalendars.map(\.identifier),
            from: calendar.startOfDay(for: now),
            to: windowEnd
        )
        let shifts = Shift.recognise(
            in: events, of: try context.fetch(FetchDescriptor<ShiftType>()), calendar: calendar)
        let plan = ArmingPlan(
            shifts: shifts, skips: try context.fetch(FetchDescriptor<Skip>()),
            now: now, windowEnd: windowEnd, calendar: calendar)
        try await armExactly(plan.wantedAlarms)
        await notifier.replaceStaleArmingNotification(firingAt: now.addingTimeInterval(48 * 60 * 60))
        return .armed(plan.shiftsInWindow)
    }

    private func record(_ result: ArmingResult, at now: Date, in context: ModelContext) {
        let record: ArmingRecord
        if let existing = try? context.fetch(FetchDescriptor<ArmingRecord>()).first {
            record = existing
        } else {
            record = ArmingRecord(latestOutcome: result.outcome)
            context.insert(record)
        }
        record.latestOutcome = result.outcome
        if case .armed = result {
            record.lastArmed = now
        }
        try? context.save()
    }

    private func pruneSkips(before today: Date, in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<Skip>(predicate: #Predicate { $0.date < today })).forEach(context.delete)
        try context.save()
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
