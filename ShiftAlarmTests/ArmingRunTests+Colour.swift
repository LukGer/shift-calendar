import Foundation
import SwiftUI
import Testing
@testable import ShiftAlarm

/// She picks each Shift Type's colour from the palette, and the ringing alarm shows it.
extension ArmingRunTests {
    @Test(arguments: [(nil, Color.indigo), (6, .brown), (0, .orange)])
    func aNewShiftTypeGetsThePickedColourOrElseTheNextOne(picked: Int?, tint: Color) async throws {
        addShiftType("Hausrunde", shortcut: "hrn", alarmSet: [])
        try container.mainContext.addShiftType(
            name: "Tagdienst", shortcut: "td", alarmSet: [Self.alarmTime("05:00")], colorIndex: picked)
        roster(allDay("td", on: "2031-03-03"))

        await arming.run()

        #expect(armedTints == ["Tagdienst": tint])
    }

    @Test(arguments: [(3, 5, Color.pink, Color.purple), (4, 4, .green, .green)])
    func theArmedAlarmIsTintedWithThePickedColourEvenWhenAnotherShiftTypeShares(
        tagdienstPick: Int, nachtdienstPick: Int, tagdienstTint: Color, nachtdienstTint: Color
    ) async {
        addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:00"]).colorIndex = tagdienstPick
        addShiftType("Nachtdienst", shortcut: "nd", alarmSet: ["18:30"]).colorIndex = nachtdienstPick
        roster(allDay("td", on: "2031-03-03"), allDay("nd", on: "2031-03-04"))

        await arming.run()

        #expect(armedTints == ["Tagdienst": tagdienstTint, "Nachtdienst": nachtdienstTint])
    }

    var armedTints: [String: Color] {
        Dictionary(alarms.armed.values.map { ($0.title, $0.tint) }) { first, _ in first }
    }
}
