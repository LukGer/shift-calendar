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
    @ObservationIgnored private let afterEachRun: @MainActor () -> Void

    init(
        openStore: @escaping @MainActor () throws -> ModelContainer,
        calendarReader: CalendarReader,
        alarmScheduler: AlarmScheduler,
        notifier: Notifier,
        clock: WallClock,
        afterEachRun: @escaping @MainActor () -> Void = {}
    ) {
        self.openStore = openStore
        self.calendarReader = calendarReader
        self.alarmScheduler = alarmScheduler
        self.notifier = notifier
        self.clock = clock
        self.afterEachRun = afterEachRun
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
            afterEachRun()
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
        if case .armed = result {
            recordLastArmed(now, in: context)
        }
        return result
    }

    private static let armingWindow = DateComponents(day: 7)
    private static let staleArmingDelay: TimeInterval = 48 * 60 * 60

    private func arm(in context: ModelContext, now: Date) async throws -> ArmingResult {
        let calendar = clock.calendar
        try pruneSkips(before: calendar.startOfDay(for: now), in: context)
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        if let reason = reasonToChangeNoAlarm(chosenCalendars: chosenCalendars) { return .skipped(reason) }
        let windowEnd = calendar.date(byAdding: Self.armingWindow, to: now)!
        let events = calendarReader.events(
            inCalendars: chosenCalendars.map(\.identifier),
            from: calendar.startOfDay(for: now),
            to: windowEnd
        )
        let shifts = Shift.recognise(
            in: events, of: try context.fetch(FetchDescriptor<ShiftType>()), calendar: calendar)
        let plan = ArmingPlan(
            shifts: shifts, skips: try dropSkipsWhoseShiftTypeChanged(on: shifts, in: context),
            now: now, windowEnd: windowEnd, calendar: calendar)
        try await armExactly(plan.wantedAlarms)
        await notifier.replaceStaleArmingNotification(firingAt: now.addingTimeInterval(Self.staleArmingDelay))
        return .armed(plan.shiftsInWindow)
    }

    private func reasonToChangeNoAlarm(chosenCalendars: [ChosenCalendar]) -> SkipReason? {
        let deviceCalendars = calendarReader.calendars()
        guard calendarReader.hasFullAccess, !deviceCalendars.isEmpty else { return .calendarNotReadable }
        guard chosenCalendars.allSatisfy({ $0.isFound(among: deviceCalendars) }) else { return .chosenCalendarMissing }
        guard alarmScheduler.isAuthorized else { return .alarmsNotAllowed }
        return nil
    }

    private func recordLastArmed(_ now: Date, in context: ModelContext) {
        let record: ArmingRecord
        if let existing = try? context.fetch(FetchDescriptor<ArmingRecord>()).first {
            record = existing
        } else {
            record = ArmingRecord()
            context.insert(record)
        }
        record.lastArmed = now
        try? context.save()
    }

    private func pruneSkips(before today: Date, in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<Skip>(predicate: #Predicate { $0.date < today })).forEach(context.delete)
        try context.save()
    }

    /// Keeps a Skip whose date has no Shift, so it still applies if the event is added again. Returns the Skips kept.
    private func dropSkipsWhoseShiftTypeChanged(on shifts: [Shift], in context: ModelContext) throws -> [Skip] {
        var kept: [Skip] = []
        for skip in try context.fetch(FetchDescriptor<Skip>()) {
            let shiftTypeIDs = shifts.filter { $0.date == skip.date }.map(\.shiftType.id)
            if shiftTypeIDs.isEmpty || shiftTypeIDs.contains(skip.shiftTypeID) {
                kept.append(skip)
            } else {
                context.delete(skip)
            }
        }
        try context.save()
        return kept
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
