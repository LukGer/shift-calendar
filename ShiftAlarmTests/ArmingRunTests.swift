import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// Drives the Arming run the way every trigger does, with a scripted calendar and a fixed clock.
/// "Now" is Sunday 2031-03-02 20:00 in Vienna, so the Arming Window ends Sunday 2031-03-09 20:00.
@MainActor
struct ArmingRunTests {
    static let vienna: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return calendar
    }()

    let container: ModelContainer
    let calendarReader = FakeCalendarReader()
    let alarms = FakeAlarmScheduler()
    let notifier = FakeNotifier()
    let clock = FixedClock(now: ArmingRunTests.instant("2031-03-02 20:00"), calendar: ArmingRunTests.vienna)
    let arming: Arming

    init() throws {
        let container = try ModelContainer(
            for: ShiftType.self, ChosenCalendar.self, Skip.self, ArmingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.container = container
        arming = Arming(
            openStore: { container },
            calendarReader: calendarReader,
            alarmScheduler: alarms,
            notifier: notifier,
            clock: clock
        )
        container.mainContext.insert(
            ChosenCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud"))
    }

    @Test func armsAShiftTypesAlarmSetOnTheShiftsDate() async {
        addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:00", "05:10"])
        roster(allDay("td", on: "2031-03-03"))

        await arming.run()

        #expect(armedAlarms == ["2031-03-03 05:00 Tagdienst", "2031-03-03 05:10 Tagdienst"])
    }

    @Test(arguments: [
        ("td", ["2031-03-03 05:00 Tagdienst"]),
        ("TD", ["2031-03-03 05:00 Tagdienst"]),
        (" Td ", ["2031-03-03 05:00 Tagdienst"]),
        ("ND ", ["2031-03-03 18:30 Nachtdienst"]),
        ("hrn", ["2031-03-03 06:15 Hausrunde"]),
        ("A11", ["2031-03-03 09:00 Ambulanz"]),
        ("e6", []),
        ("nd Station 3", []),
        ("t d", []),
        ("U", []),
        ("frei", []),
        ("Allerheiligen", []),
    ])
    func recognisesAnAllDayEventWhoseWholeTitleIsAShortcut(title: String, expected: [String]) async {
        addHerShiftTypes()
        roster(allDay(title, on: "2031-03-03"))

        await arming.run()

        #expect(armedAlarms == expected)
    }

    @Test(arguments: ["td", "nd"])
    func ignoresTimedEvents(title: String) async {
        addHerShiftTypes()
        roster(timed(title, at: "2031-03-03 07:00"))

        await arming.run()

        #expect(armedAlarms == [])
    }

    @Test(arguments: [
        (
            [("nd", "2031-03-03", "2031-03-05")],
            ["2031-03-03 18:30 Nachtdienst", "2031-03-04 18:30 Nachtdienst", "2031-03-05 18:30 Nachtdienst"]
        ),
        (
            [("td", "2031-03-03", "2031-03-03"), ("hrn", "2031-03-03", "2031-03-03")],
            ["2031-03-03 05:00 Tagdienst", "2031-03-03 06:15 Hausrunde"]
        ),
        (
            [("td", "2031-03-03", "2031-03-03"), ("TD", "2031-03-03", "2031-03-03")],
            ["2031-03-03 05:00 Tagdienst"]
        ),
        (
            [("td", "2031-03-03", "2031-03-03"), ("td", "2031-03-02", "2031-03-04")],
            ["2031-03-03 05:00 Tagdienst", "2031-03-04 05:00 Tagdienst"]
        ),
    ])
    func armsEveryShiftOnEveryDateItsEventsCover(events: [(String, String, String)], expected: [String]) async {
        addHerShiftTypes()
        for (title, first, last) in events {
            roster(allDay(title, from: first, through: last))
        }

        await arming.run()

        #expect(armedAlarms == expected)
    }

    @Test func mergesIdenticalInstantsIntoOneAlarmForTheShiftTypeCreatedFirst() async {
        addShiftType("Hausrunde", shortcut: "hrn", alarmSet: ["05:00", "06:15"], createdAt: "2031-01-03 00:00")
        let tagdienst = addShiftType(
            "Tagdienst", shortcut: "td", alarmSet: ["05:00", "05:10"], createdAt: "2031-01-01 00:00")
        roster(allDay("hrn", on: "2031-03-03"), allDay("td", on: "2031-03-03"))

        await arming.run()

        #expect(armedAlarms == [
            "2031-03-03 05:00 Tagdienst", "2031-03-03 05:10 Tagdienst", "2031-03-03 06:15 Hausrunde",
        ])
        #expect(alarms.armed.values.first { $0.title == "Tagdienst" }?.tint == tagdienst.color)
    }

    @Test(arguments: [
        ("2031-03-02", "19:59", false),
        ("2031-03-02", "20:00", false),
        ("2031-03-02", "20:01", true),
        ("2031-03-09", "20:00", true),
        ("2031-03-09", "20:01", false),
        ("2031-03-10", "05:00", false),
    ])
    func armsOnlyInstantsInsideTheArmingWindow(date: String, time: String, isArmed: Bool) async {
        addShiftType("Nachtdienst", shortcut: "nd", alarmSet: [time])
        roster(allDay("nd", on: date))

        await arming.run()

        #expect(armedAlarms == (isArmed ? ["\(date) \(time) Nachtdienst"] : []))
    }

    /// Expected IDs are RFC 4122 version-5 UUIDs computed independently (Python's `uuid.uuid5`)
    /// in the app's namespace, from "<Shift date>|<Shift Type identity>|<alarm time>".
    @Test(arguments: [
        ("td", "2031-03-03", "05:00", "82C5E6E3-AD1E-5C50-8D42-5E2689A6D2D7"),
        ("nd", "2031-03-04", "18:30", "11A9EA51-573A-556E-9C4F-3C659FEC817E"),
    ])
    func namesEachAlarmAfterItsShiftDateShiftTypeAndTime(
        shortcut: String, date: String, time: String, expectedID: String
    ) async {
        let shiftType = addShiftType("Dienst", shortcut: shortcut, alarmSet: [time])
        shiftType.id = UUID(uuidString: "6F1C5B0E-2D3A-4C8B-9E7F-1A2B3C4D5E6F")!
        roster(allDay(shortcut, on: date))

        await arming.run()

        #expect(Set(alarms.armed.keys) == [UUID(uuidString: expectedID)!])
    }

    @Test func aRunWithNothingChangedSchedulesAndCancelsNothing() async {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"), allDay("nd", from: "2031-03-05", through: "2031-03-06"))
        await arming.run()
        let callsAfterFirstRun = alarms.calls

        await arming.run()

        #expect(alarms.calls == callsAfterFirstRun)
    }

    enum Change: CaseIterable {
        case shiftMovedToAnotherDate, shiftTypeChanged, alarmTimeChanged, shiftDeleted, calendarUnchosen
    }

    @Test(arguments: [
        (Change.shiftMovedToAnotherDate, ["2031-03-04 05:00 Tagdienst"]),
        (Change.shiftTypeChanged, ["2031-03-03 06:15 Hausrunde"]),
        (Change.alarmTimeChanged, ["2031-03-03 04:45 Tagdienst"]),
        (Change.shiftDeleted, []),
        (Change.calendarUnchosen, []),
    ])
    func replacesAlarmsBySchedulingTheNewOnesBeforeCancellingTheOldOnes(change: Change, expected: [String]) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()
        let oldIDs = Set(alarms.armed.keys)
        let callsBefore = alarms.calls.count

        try apply(change)
        await arming.run()

        #expect(armedAlarms == expected)
        let newIDs = Set(alarms.armed.keys)
        #expect(Array(alarms.calls.dropFirst(callsBefore)) == newIDs.map { .schedule($0) } + oldIDs.map { .cancel($0) })
    }

    @Test func cancelsLeftoverAlarmsFromAnEarlierInstall() async {
        let leftover = WantedAlarm(
            id: UUID(), instant: Self.instant("2031-03-04 05:00"), title: "Tagdienst", tint: .orange)
        alarms.arm(leftover)
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))

        await arming.run()

        #expect(armedAlarms == ["2031-03-03 05:00 Tagdienst"])
        #expect(alarms.calls.last == .cancel(leftover.id))
    }

    @Test func aRunThatDiesBeforeCancellingLeavesADuplicateNotAGapAndTheNextRunTidiesUp() async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()
        try apply(.alarmTimeChanged)

        alarms.cancellingFails = true
        await arming.run()
        #expect(armedAlarms == ["2031-03-03 04:45 Tagdienst", "2031-03-03 05:00 Tagdienst"])

        alarms.cancellingFails = false
        await arming.run()
        #expect(armedAlarms == ["2031-03-03 04:45 Tagdienst"])
    }

    @Test func reportsEachShiftInTheWindowWithTheAlarmTimesThatWillRing() async {
        addHerShiftTypes()
        roster(
            allDay("nd", on: "2031-03-02"),
            allDay("hrn", on: "2031-03-03"),
            allDay("td", on: "2031-03-03"),
            allDay("e6", on: "2031-03-04"),
            allDay("frei", on: "2031-03-05"),
            allDay("td", on: "2031-03-10")
        )

        let result = await arming.run()

        #expect(Self.shifts(in: result) == [
            "2031-03-03 Tagdienst 05:00",
            "2031-03-03 Hausrunde 06:15",
            "2031-03-04 Spät",
        ])
    }

    @Test func keepsAnAlarmSetInTimeOrder() async {
        let tagdienst = addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:10", "04:50"])
        tagdienst.replaceAlarmSet(with: [AlarmTime(hour: 5, minute: 20), AlarmTime(hour: 4, minute: 40)])
        roster(allDay("td", on: "2031-03-03"))

        let result = await arming.run()

        #expect(Self.shifts(in: result) == ["2031-03-03 Tagdienst 04:40 05:20"])
    }

    @Test func aSuccessfulRunMovesTheStaleArmingNotificationTo48HoursFromNow() async {
        await arming.run()

        #expect(notifier.staleArmingNotificationDate == Self.instant("2031-03-04 20:00"))
    }

    @Test func aSuccessfulRunRecordsItAsLastArmed() async {
        await arming.run()

        #expect(record?.latestOutcome == .armed)
        #expect(record?.lastArmed == Self.instant("2031-03-02 20:00"))
    }

    @Test func aRunThatFailsReportsItAndLeavesTheStaleArmingNotificationAndLastArmedAlone() async {
        alarms.arm(WantedAlarm(id: UUID(), instant: Self.instant("2031-03-04 05:00"), title: "Tagdienst", tint: .orange))
        alarms.cancellingFails = true

        let result = await arming.run()

        #expect(result == .failed)
        #expect(record?.latestOutcome == .failed)
        #expect(record?.lastArmed == nil)
        #expect(notifier.staleArmingNotificationDate == nil)
    }

    enum Blindness: CaseIterable {
        case noFullCalendarAccess, noCalendarsVisible, chosenCalendarOnlyInAnotherAccount, chosenCalendarFoundTwice
        case alarmsNotAllowed
    }

    @Test(arguments: [
        (Blindness.noFullCalendarAccess, SkipReason.calendarNotReadable),
        (Blindness.noCalendarsVisible, SkipReason.calendarNotReadable),
        (Blindness.chosenCalendarOnlyInAnotherAccount, SkipReason.chosenCalendarMissing),
        (Blindness.chosenCalendarFoundTwice, SkipReason.chosenCalendarMissing),
        (Blindness.alarmsNotAllowed, SkipReason.alarmsNotAllowed),
    ])
    func aBlindRunLeavesArmedAlarmsAndLastArmedUntouched(blindness: Blindness, reason: SkipReason) async {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()
        let armedBefore = armedAlarms
        let callsBefore = alarms.calls
        calendarReader.eventsByCalendar["dienste"] = [allDay("nd", on: "2031-03-04")]
        clock.now = Self.instant("2031-03-02 21:00")

        make(blindness)
        let result = await arming.run()

        #expect(result == .skipped(reason))
        #expect(alarms.calls == callsBefore)
        #expect(armedAlarms == armedBefore)
        #expect(record?.latestOutcome == .skipped(reason))
        #expect(record?.lastArmed == Self.instant("2031-03-02 20:00"))
        #expect(notifier.staleArmingNotificationDate == Self.instant("2031-03-04 20:00"))
    }

    @Test func findsAChosenCalendarAgainByTitleAndAccountWhenItsIdentifierChanges() async throws {
        addHerShiftTypes()
        calendarReader.deviceCalendars = [
            DeviceCalendar(identifier: "dienste-2", title: "Dienste", sourceIdentifier: "icloud"),
            DeviceCalendar(identifier: "dienste-google", title: "Dienste", sourceIdentifier: "google"),
        ]
        roster(allDay("td", on: "2031-03-03"), in: "dienste-2")

        await arming.run()

        #expect(armedAlarms == ["2031-03-03 05:00 Tagdienst"])
        #expect(try container.mainContext.fetch(FetchDescriptor<ChosenCalendar>()).map(\.identifier) == ["dienste-2"])
    }

    @Test func overlappingRunsTakeTurns() async {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"), allDay("nd", on: "2031-03-04"))

        async let first = arming.run()
        async let second = arming.run()
        let results = await [first, second]

        #expect(results.allSatisfy { $0 != .failed })
        #expect(alarms.calls.count == 2)
    }

    // MARK: - Fixtures

    static func shifts(in result: ArmingResult) -> [String] {
        guard case .armed(let shifts) = result else { return [] }
        return shifts.map { shift in
            let rings = shift.isSkipped ? ["Skipped"] : shift.alarmTimes.map(\.text)
            return ([String(text(shift.date).prefix(10)), shift.name] + rings).joined(separator: " ")
        }
    }

    func apply(_ change: Change) throws {
        let context = container.mainContext
        switch change {
        case .shiftMovedToAnotherDate:
            calendarReader.eventsByCalendar["dienste"] = [allDay("td", on: "2031-03-04")]
        case .shiftTypeChanged:
            calendarReader.eventsByCalendar["dienste"] = [allDay("hrn", on: "2031-03-03")]
        case .alarmTimeChanged:
            let tagdienst = try context.fetch(FetchDescriptor<ShiftType>()).first { $0.shortcut == "td" }
            tagdienst?.replaceAlarmSet(with: [AlarmTime(hour: 4, minute: 45)])
        case .shiftDeleted:
            calendarReader.eventsByCalendar["dienste"] = []
        case .calendarUnchosen:
            try context.fetch(FetchDescriptor<ChosenCalendar>()).forEach(context.delete)
        }
    }

    /// Read through a context of its own, as Settings and the home banner see it after the run.
    var record: ArmingRecord? {
        try? ModelContext(container).fetch(FetchDescriptor<ArmingRecord>()).first
    }

    func make(_ blindness: Blindness) {
        switch blindness {
        case .noFullCalendarAccess:
            calendarReader.hasFullAccess = false
        case .noCalendarsVisible:
            calendarReader.deviceCalendars = []
        case .chosenCalendarOnlyInAnotherAccount:
            calendarReader.deviceCalendars = [
                DeviceCalendar(identifier: "dienste-google", title: "Dienste", sourceIdentifier: "google"),
            ]
        case .chosenCalendarFoundTwice:
            calendarReader.deviceCalendars = [
                DeviceCalendar(identifier: "dienste-2", title: "Dienste", sourceIdentifier: "icloud"),
                DeviceCalendar(identifier: "dienste-3", title: "Dienste", sourceIdentifier: "icloud"),
            ]
        case .alarmsNotAllowed:
            alarms.isAuthorized = false
        }
    }

    /// Her real Shortcuts. Spät (e6) is a late Shift and needs no wake-up.
    func addHerShiftTypes() {
        addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:00"], createdAt: "2031-01-01 00:00")
        addShiftType("Nachtdienst", shortcut: "nd", alarmSet: ["18:30"], createdAt: "2031-01-02 00:00")
        addShiftType("Hausrunde", shortcut: "hrn", alarmSet: ["06:15"], createdAt: "2031-01-03 00:00")
        addShiftType("Ambulanz", shortcut: "a11", alarmSet: ["09:00"], createdAt: "2031-01-04 00:00")
        addShiftType("Spät", shortcut: "e6", alarmSet: [], createdAt: "2031-01-05 00:00")
    }

    var armedAlarms: [String] {
        alarms.armed.values
            .map { "\(Self.text($0.instant)) \($0.title)" }
            .sorted()
    }

    @discardableResult
    func addShiftType(
        _ name: String, shortcut: String, alarmSet: [String], createdAt: String = "2031-01-01 00:00"
    ) -> ShiftType {
        let colorIndex = (try? container.mainContext.fetchCount(FetchDescriptor<ShiftType>())) ?? 0
        let shiftType = ShiftType(
            name: name,
            shortcut: shortcut,
            alarmSet: alarmSet.map(Self.alarmTime),
            colorIndex: colorIndex,
            createdAt: Self.instant(createdAt)
        )
        container.mainContext.insert(shiftType)
        return shiftType
    }

    func roster(_ events: CalendarEvent..., in calendar: String = "dienste") {
        calendarReader.eventsByCalendar[calendar, default: []] += events
    }

    func allDay(_ title: String, on day: String) -> CalendarEvent {
        allDay(title, from: day, through: day)
    }

    /// EventKit reports an all-day event's end as 23:59:59 on its last day.
    func allDay(_ title: String, from first: String, through last: String) -> CalendarEvent {
        CalendarEvent(
            title: title,
            startDate: Self.instant("\(first) 00:00"),
            endDate: Self.instant("\(last) 23:59").addingTimeInterval(59),
            isAllDay: true
        )
    }

    func timed(_ title: String, at start: String) -> CalendarEvent {
        let startDate = Self.instant(start)
        return CalendarEvent(
            title: title, startDate: startDate, endDate: startDate.addingTimeInterval(8 * 60 * 60), isAllDay: false)
    }

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = vienna
        formatter.timeZone = vienna.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func instant(_ text: String) -> Date {
        formatter.date(from: text)!
    }

    static func text(_ instant: Date) -> String {
        formatter.string(from: instant)
    }

    static func alarmTime(_ text: String) -> AlarmTime {
        let parts = text.split(separator: ":").map { Int($0)! }
        return AlarmTime(hour: parts[0], minute: parts[1])
    }
}
