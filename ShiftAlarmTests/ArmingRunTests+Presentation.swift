import Foundation
import Testing
@testable import ShiftAlarm

/// An armed alarm looks and sounds as its Shift Type and Alarm Set do now, even after she changes them.
extension ArmingRunTests {
    @Test(arguments: [
        ("Frühdienst", 0, nil as Tone?, ["2031-03-03 05:00 Frühdienst orange default"]),
        ("Tagdienst", 1, nil, ["2031-03-03 05:00 Tagdienst indigo default"]),
        ("Tagdienst", 0, .kalimba, ["2031-03-03 05:00 Tagdienst orange kalimba"]),
    ])
    func reArmsTheArmedAlarmWhenSheChangesHowItLooksOrSounds(
        name: String, colorIndex: Int, tone: Tone?, expected: [String]
    ) async {
        let tagdienst = addShiftType("Tagdienst", shortcut: "td", alarmSet: ["05:00"])
        tagdienst.colorIndex = 0
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()

        tagdienst.name = name
        tagdienst.colorIndex = colorIndex
        tagdienst.replaceAlarmSet(with: [Self.alarm("05:00", tone: tone)])
        await arming.run()

        #expect(armedPresentations == expected)
    }

    var armedPresentations: [String] {
        alarms.armed.values
            .map { "\(Self.text($0.instant)) \($0.title) \($0.tint) \($0.tone?.rawValue ?? "default")" }
            .sorted()
    }
}
