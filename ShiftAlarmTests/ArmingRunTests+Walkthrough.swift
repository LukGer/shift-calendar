import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// The walkthrough's last page: she names the Shortcuts found in her chosen calendars, or leaves them unnamed.
extension ArmingRunTests {
    @Test(arguments: [
        (["td": "Tagdienst", "U": ""], ["2031-03-03 Tagdienst"], ["U"]),
        (["td": " Tagdienst ", "U": "  "], ["2031-03-03 Tagdienst"], ["U"]),
        (["td": "Tagdienst", "U": "Urlaub"], ["2031-03-03 Tagdienst", "2031-03-04 Urlaub"], []),
        ([:], [], ["td", "U"]),
    ])
    func namingAFoundShortcutMakesAShiftTypeThatRingsNothingAndLeavingItUnnamedIgnoresIt(
        names: [String: String], shifts: [String], stillNotAShiftType: [String]
    ) async throws {
        roster(allDay("td", on: "2031-03-03"), allDay("U", on: "2031-03-04"))

        try container.mainContext.addShiftTypes(for: try unmatchedTitles(), named: names)
        let result = await arming.run()

        #expect(Self.shifts(in: result) == shifts)
        #expect(try unmatchedTitles() == stillNotAShiftType)
    }

    @Test func eachNamedShortcutGetsTheNextColourInTheOrderListed() async throws {
        addShiftType("Hausrunde", shortcut: "hrn", alarmSet: [])
        roster(allDay("td", on: "2031-03-03"), allDay("nd", on: "2031-03-04"))

        try container.mainContext.addShiftTypes(
            for: try unmatchedTitles(), named: ["nd": "Nachtdienst", "td": "Tagdienst"])
        let result = await arming.run()

        guard case .armed(let shifts) = result else { Issue.record("Not armed: \(result)"); return }
        #expect(shifts.map(\.name) == ["Tagdienst", "Nachtdienst"])
        #expect(shifts.map(\.color) == [ShiftType.palette[2], ShiftType.palette[1]])
    }
}
