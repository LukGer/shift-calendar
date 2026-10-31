import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// Skipping a Shift so it rings nothing, without editing her calendar.
extension ArmingRunTests {
    nonisolated static let skippableShifts = [
        ("2031-03-03", "Tagdienst", ["2031-03-03 06:15 Hausrunde", "2031-03-04 05:00 Tagdienst"]),
        ("2031-03-03", "Hausrunde", ["2031-03-03 05:00 Tagdienst", "2031-03-04 05:00 Tagdienst"]),
        ("2031-03-04", "Tagdienst", ["2031-03-03 05:00 Tagdienst", "2031-03-03 06:15 Hausrunde"]),
    ]

    @Test(arguments: skippableShifts)
    func skippingAShiftCancelsItsAlarmsAndKeepsItListedAsSkipped(
        date: String, name: String, expected: [String]
    ) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"), allDay("hrn", on: "2031-03-03"), allDay("td", on: "2031-03-04"))
        let before = await arming.run()

        try toggleSkip(date, name, in: before)
        let after = await arming.run()

        #expect(armedAlarms == expected)
        #expect(Self.shifts(in: after).filter { $0.hasSuffix("Skipped") } == ["\(date) \(name) Skipped"])
    }

    @Test(arguments: skippableShifts)
    func unSkippingAShiftArmsItsAlarmsAgain(date: String, name: String, expected: [String]) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"), allDay("hrn", on: "2031-03-03"), allDay("td", on: "2031-03-04"))
        let before = await arming.run()
        let armedBefore = alarms.armed
        try toggleSkip(date, name, in: before)
        let skipped = await arming.run()

        try toggleSkip(date, name, in: skipped)
        let after = await arming.run()

        #expect(alarms.armed == armedBefore)
        #expect(after == before)
    }

    @Test(arguments: ["td", "TD", " td "])
    func aShiftStaysSkippedWhenItsEventIsDeletedAndAddedAgain(reAddedTitle: String) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        try toggleSkip("2031-03-03", "Tagdienst", in: await arming.run())
        await arming.run()

        calendarStore.eventsByCalendar["dienste"] = []
        await arming.run()
        roster(allDay(reAddedTitle, on: "2031-03-03"))
        let result = await arming.run()

        #expect(armedAlarms == [])
        #expect(Self.shifts(in: result) == ["2031-03-03 Tagdienst Skipped"])
    }

    @Test(arguments: [
        ("hrn", "2031-03-03 Hausrunde 06:15", ["2031-03-03 06:15 Hausrunde"]),
        ("nd", "2031-03-03 Nachtdienst 18:30", ["2031-03-03 18:30 Nachtdienst"]),
    ])
    func aSkipStopsApplyingWhenTheShiftChangesToAnotherShiftType(
        newTitle: String, expectedShift: String, expectedAlarms: [String]
    ) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        try toggleSkip("2031-03-03", "Tagdienst", in: await arming.run())
        await arming.run()

        calendarStore.eventsByCalendar["dienste"] = [allDay(newTitle, on: "2031-03-03")]
        let result = await arming.run()

        #expect(armedAlarms == expectedAlarms)
        #expect(Self.shifts(in: result) == [expectedShift])
    }

    @Test(arguments: ["td", "hrn", " TD "])
    func aSkipDropsWhenTheShiftChangesToAnotherShiftType(otherTitle: String) async throws {
        addHerShiftTypes()
        roster(allDay("nd", on: "2031-03-03"))
        try toggleSkip("2031-03-03", "Nachtdienst", in: await arming.run())
        await arming.run()

        calendarStore.eventsByCalendar["dienste"] = [allDay(otherTitle, on: "2031-03-03")]
        await arming.run()
        calendarStore.eventsByCalendar["dienste"] = [allDay("nd", on: "2031-03-03")]
        let result = await arming.run()

        #expect(armedAlarms == ["2031-03-03 18:30 Nachtdienst"])
        #expect(Self.shifts(in: result) == ["2031-03-03 Nachtdienst 18:30"])
    }

    /// "Now" is 2031-03-02 20:00, so a Skip for that day is still today's.
    @Test(arguments: [
        ("2031-02-01", false),
        ("2031-03-01", false),
        ("2031-03-02", true),
        ("2031-03-03", true),
        ("2031-03-20", true),
    ])
    func prunesSkipsForPastDatesAtTheStartOfEachRun(date: String, isKept: Bool) async throws {
        let context = container.mainContext
        context.insert(Skip(date: Self.instant("\(date) 00:00"), shiftTypeID: UUID()))
        try context.save()

        await arming.run()

        #expect(try context.fetchCount(FetchDescriptor<Skip>()) == (isKept ? 1 : 0))
    }

    // MARK: - Fixtures

    func toggleSkip(_ date: String, _ name: String, in result: ArmingResult) throws {
        let shift = try #require(Self.windowShift(on: date, name, in: result))
        try container.mainContext.toggleSkip(of: shift)
    }

    static func windowShift(on date: String, _ name: String, in result: ArmingResult) -> WindowShift? {
        guard case .armed(let shifts) = result else { return nil }
        return shifts.first { $0.date == instant("\(date) 00:00") && $0.name == name }
    }
}
