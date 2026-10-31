import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// The month grid on Home: every day of a month's weeks with the Shifts on it.
/// 2031-03-01 is a Saturday, and 2031-12-01 a Monday.
extension ArmingRunTests {
    @Test(arguments: [
        ("2031-03", 1, "2031-02-23", "2031-04-05", 31),
        ("2031-03", 2, "2031-02-24", "2031-04-06", 31),
        ("2031-03", 7, "2031-03-01", "2031-04-04", 31),
        ("2031-02", 1, "2031-01-26", "2031-03-01", 28),
        ("2031-02", 2, "2031-01-27", "2031-03-02", 28),
        ("2031-12", 1, "2031-11-30", "2032-01-03", 31),
        ("2031-12", 2, "2031-12-01", "2032-01-04", 31),
    ])
    func aMonthsGridRunsInWholeWeeksFromTheLocalesFirstWeekday(
        month: String, firstWeekday: Int, firstDay: String, lastDay: String, daysInMonth: Int
    ) throws {
        let days = try monthOfShifts(month, firstWeekday: firstWeekday)

        #expect(days.first.map { Self.day($0.date) } == firstDay)
        #expect(days.last.map { Self.day($0.date) } == lastDay)
        #expect(days.count % 7 == 0)
        #expect(days.filter(\.isInMonth).count == daysInMonth)
        #expect(days.filter(\.isInMonth).allSatisfy { Self.day($0.date).hasPrefix(month) })
    }

    @Test(arguments: [
        ("2031-03", 1, ["2031-03-02"]),
        ("2031-02", 2, ["2031-03-02"]),
        ("2031-02", 1, []),
        ("2031-04", 2, []),
    ])
    func todayIsMarkedInAnyGridItAppearsIn(month: String, firstWeekday: Int, expected: [String]) throws {
        let days = try monthOfShifts(month, firstWeekday: firstWeekday)

        #expect(days.filter(\.isToday).map { Self.day($0.date) } == expected)
    }

    /// With weeks from Sunday, February's grid ends on 2031-03-01 and April's starts on 2031-03-30.
    @Test(arguments: [
        ("2031-03", ["2031-02-23", "2031-03-01"]),
        ("2031-02", ["2031-01-26", "2031-03-01"]),
        ("2031-04", []),
    ])
    func theDaysBeforeTodayArePast(month: String, firstAndLastPastDay: [String]) throws {
        let pastDays = try monthOfShifts(month).filter(\.isPast).map { Self.day($0.date) }

        #expect([pastDays.first, pastDays.last].compactMap(\.self) == firstAndLastPastDay)
        #expect(try monthOfShifts(month).prefix(pastDays.count).allSatisfy(\.isPast))
    }

    /// March's grid runs from Sunday 2031-02-23 to Saturday 2031-04-05.
    nonisolated static let rostersInMarchsGrid: [([(String, String, String)], [String])] = [
        ([("td", "2031-03-03", "2031-03-03")], ["2031-03-03 td"]),
        ([("td", "2031-02-23", "2031-02-23"), ("nd", "2031-04-05", "2031-04-05")], ["2031-02-23 td", "2031-04-05 nd"]),
        ([("td", "2031-02-22", "2031-02-22"), ("nd", "2031-04-06", "2031-04-06")], []),
        ([("hrn", "2031-03-03", "2031-03-03"), ("td", "2031-03-03", "2031-03-03")], ["2031-03-03 td hrn"]),
        ([("td", "2031-03-03", "2031-03-03"), (" TD ", "2031-03-03", "2031-03-03")], ["2031-03-03 td"]),
        ([("nd", "2031-02-21", "2031-02-24")], ["2031-02-23 nd", "2031-02-24 nd"]),
        ([("a11", "2031-04-04", "2031-04-08")], ["2031-04-04 a11", "2031-04-05 a11"]),
        ([("e6", "2031-03-31", "2031-04-01")], ["2031-03-31 e6", "2031-04-01 e6"]),
        ([("U", "2031-03-03", "2031-03-03"), ("frei", "2031-03-04", "2031-03-04")], []),
    ]

    @Test(arguments: rostersInMarchsGrid)
    func eachGridDayHasTheShiftsOnItIncludingLeadingAndTrailingDays(
        events: [(String, String, String)], expected: [String]
    ) throws {
        addHerShiftTypes()
        for (title, first, last) in events {
            roster(allDay(title, from: first, through: last))
        }

        #expect(try daysWithShifts(in: "2031-03") == expected)
    }

    @Test(arguments: ["td", "nd"])
    func leavesTimedEventsOffTheGrid(title: String) throws {
        addHerShiftTypes()
        roster(timed(title, at: "2031-03-03 07:00"))

        #expect(try daysWithShifts(in: "2031-03") == [])
    }

    /// The Arming Window ends on 2031-03-09; Skips beyond it show too.
    @Test(arguments: [
        ("2031-03-03", "td", ["2031-03-03 td"]),
        ("2031-03-20", "td", ["2031-03-20 td"]),
        ("2031-03-20", "hrn", ["2031-03-20 hrn"]),
        ("2031-03-03", "nd", []),
        ("2031-03-21", "td", []),
    ])
    func aSkippedShiftIsMarkedSkippedInsideOrBeyondTheArmingWindow(
        date: String, shortcut: String, expected: [String]
    ) throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"), allDay("td", on: "2031-03-20"), allDay("hrn", on: "2031-03-20"))
        try skip(date, shortcut)

        #expect(try shifts(in: "2031-03", where: \.isSkipped) == expected)
    }

    /// "Now" is 2031-03-02 20:00, so the Arming Window covers 2031-03-02 to 2031-03-09.
    @Test(arguments: [
        ("2031-02-28", false),
        ("2031-03-01", false),
        ("2031-03-02", true),
        ("2031-03-05", true),
        ("2031-03-09", true),
        ("2031-03-10", false),
        ("2031-04-01", false),
    ])
    func aShiftIsMarkedWhenItsDateIsInTheArmingWindow(date: String, isInArmingWindow: Bool) throws {
        addHerShiftTypes()
        roster(allDay("td", on: date))

        #expect(try shifts(in: "2031-03", where: \.isInArmingWindow) == (isInArmingWindow ? ["\(date) td"] : []))
    }

    enum EventsBehindAShift: CaseIterable {
        case aSingleDayEventAhead, aSingleDayEventToday, twoSingleDayEvents
        case aPastEvent, aMultiDayEvent, aRecurringEvent, anEventInACalendarSheCantEdit
        case aSingleDayEventAndARecurringOne, aSingleDayEventAndOneInACalendarSheCantEdit
    }

    @Test(arguments: [
        (EventsBehindAShift.aSingleDayEventAhead, false),
        (.aSingleDayEventToday, false),
        (.twoSingleDayEvents, false),
        (.aPastEvent, true),
        (.aMultiDayEvent, true),
        (.aRecurringEvent, true),
        (.anEventInACalendarSheCantEdit, true),
        (.aSingleDayEventAndARecurringOne, true),
        (.aSingleDayEventAndOneInACalendarSheCantEdit, true),
    ])
    func aShiftIsLockedWhenItIsPastOrAnyEventBehindItIsMultiDayRecurringOrInACalendarSheCantEdit(
        events: EventsBehindAShift, isLocked: Bool
    ) throws {
        addHerShiftTypes()
        let date = try roster(events)

        #expect(try shifts(in: "2031-03", where: \.isLocked).contains("\(date) td") == isLocked)
    }

    // MARK: - Fixtures

    /// Puts a Tagdienst on a date behind `events`, and returns that date.
    func roster(_ events: EventsBehindAShift) throws -> String {
        var recurring = allDay("td", on: "2031-03-03")
        recurring.isRecurring = true
        switch events {
        case .aSingleDayEventAhead:
            roster(allDay("td", on: "2031-03-03"))
        case .aSingleDayEventToday:
            roster(allDay("td", on: "2031-03-02"))
            return "2031-03-02"
        case .twoSingleDayEvents:
            roster(allDay("td", on: "2031-03-03"), allDay("TD", on: "2031-03-03"))
        case .aPastEvent:
            roster(allDay("td", on: "2031-03-01"))
            return "2031-03-01"
        case .aMultiDayEvent:
            roster(allDay("td", from: "2031-03-03", through: "2031-03-04"))
        case .aRecurringEvent:
            roster(recurring)
        case .anEventInACalendarSheCantEdit:
            try chooseACalendarSheCantEdit()
            roster(allDay("td", on: "2031-03-03"), in: "feiertage")
        case .aSingleDayEventAndARecurringOne:
            roster(allDay("td", on: "2031-03-03"), recurring)
        case .aSingleDayEventAndOneInACalendarSheCantEdit:
            try chooseACalendarSheCantEdit()
            roster(allDay("td", on: "2031-03-03"))
            roster(allDay("td", on: "2031-03-03"), in: "feiertage")
        }
        return "2031-03-03"
    }

    /// A subscribed calendar, say.
    func chooseACalendarSheCantEdit() throws {
        calendarStore.deviceCalendars.append(
            DeviceCalendar(identifier: "feiertage", title: "Feiertage", sourceIdentifier: "icloud", isEditable: false))
        container.mainContext.insert(
            ChosenCalendar(identifier: "feiertage", title: "Feiertage", sourceIdentifier: "icloud"))
        try container.mainContext.save()
    }

    /// "2031-03-03 td" for each Shift in the month's grid that `isMarked`.
    func shifts(in month: String, where isMarked: (GridShift) -> Bool) throws -> [String] {
        try monthOfShifts(month).flatMap { day in
            day.shifts.filter(isMarked).map { "\(Self.day(day.date)) \($0.shiftType.shortcut)" }
        }
    }

    func skip(_ date: String, _ shortcut: String) throws {
        let context = container.mainContext
        let shiftType = try #require(try context.fetch(FetchDescriptor<ShiftType>()).first { $0.shortcut == shortcut })
        context.insert(Skip(date: Self.instant("\(date) 00:00"), shiftTypeID: shiftType.id))
        try context.save()
    }

    /// "2031-03-03 td hrn" for each grid day with Shifts.
    func daysWithShifts(in month: String) throws -> [String] {
        try monthOfShifts(month).filter { !$0.shifts.isEmpty }.map { day in
            ([Self.day(day.date)] + day.shifts.map(\.shiftType.shortcut)).joined(separator: " ")
        }
    }

    func monthOfShifts(_ month: String, firstWeekday: Int = 1) throws -> [GridDay] {
        var calendar = Self.vienna
        calendar.firstWeekday = firstWeekday
        let context = container.mainContext
        return calendarStore.monthOfShifts(
            containing: Self.instant("\(month)-15 12:00"),
            in: try context.fetch(FetchDescriptor<ChosenCalendar>()),
            of: try context.fetch(FetchDescriptor<ShiftType>()),
            skips: try context.fetch(FetchDescriptor<Skip>()),
            clock: FixedClock(now: clock.now, calendar: calendar)
        )
    }

    static func day(_ date: Date) -> String {
        String(text(date).prefix(10))
    }
}
