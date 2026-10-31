import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// The "Not a Shift Type" section in Settings: all-day titles in her chosen calendars that match no Shift Type.
extension ArmingRunTests {
    @Test(arguments: [
        (["U"], ["U"]),
        (["frei", " frei ", "FREI"], ["frei"]),
        (["U", "frei", "Allerheiligen"], ["Allerheiligen", "frei", "U"]),
        (["td", "ND ", "e6", "nd Station 3"], ["nd Station 3"]),
        (["sd", "SD", "td"], ["sd"]),
        (["", " "], []),
    ])
    func listsEachUnmatchedAllDayTitleOnceTrimmedAndInAnyCase(titles: [String], expected: [String]) throws {
        addHerShiftTypes()
        for title in titles {
            roster(allDay(title, on: "2031-03-03"))
        }

        #expect(try unmatchedTitles() == expected)
    }

    @Test(arguments: ["sd", "Besprechung", "td"])
    func leavesOutTimedEvents(title: String) throws {
        addHerShiftTypes()
        roster(timed(title, at: "2031-03-03 07:00"))

        #expect(try unmatchedTitles() == [])
    }

    @Test(arguments: ["td", " Td ", "ND ", "e6", "nd Station 3", "t d", "sd", "U", "frei", "Allerheiligen"])
    func anAllDayTitleIsEitherAShiftOrNotAShiftType(title: String) async throws {
        addHerShiftTypes()
        roster(allDay(title, on: "2031-03-03"))

        let result = await arming.run()

        #expect(Self.shifts(in: result).isEmpty != (try unmatchedTitles()).isEmpty)
    }

    func unmatchedTitles() throws -> [String] {
        let context = container.mainContext
        return calendarStore.unmatchedTitles(
            in: try context.fetch(FetchDescriptor<ChosenCalendar>()),
            of: try context.fetch(FetchDescriptor<ShiftType>()),
            now: clock.now,
            calendar: clock.calendar
        )
    }
}
