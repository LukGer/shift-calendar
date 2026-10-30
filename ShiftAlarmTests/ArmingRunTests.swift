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
            for: ShiftType.self, ChosenCalendar.self,
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

    // MARK: - Fixtures

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
