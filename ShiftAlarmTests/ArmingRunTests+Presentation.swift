import Foundation
import Testing
@testable import ShiftAlarm

/// An armed alarm rings as its Shift Type looks now, even after she changes it.
extension ArmingRunTests {
    @Test(arguments: [
        ("Frühdienst", 0, ["2031-03-03 05:00 Frühdienst orange"]),
        ("Tagdienst", 1, ["2031-03-03 05:00 Tagdienst indigo"]),
    ])
    func reArmsTheArmedAlarmWhenSheChangesHowItLooks(name: String, colorIndex: Int, expected: [String]) async {
        let tagdienst = addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:00"])
        tagdienst.colorIndex = 0
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()

        tagdienst.name = name
        tagdienst.colorIndex = colorIndex
        await arming.run()

        #expect(armedLooks == expected)
    }

    var armedLooks: [String] {
        alarms.armed.values
            .map { "\(Self.text($0.instant)) \($0.title) \($0.tint)" }
            .sorted()
    }
}
