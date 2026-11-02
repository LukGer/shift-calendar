import Foundation
import Testing
@testable import ShiftAlarm

struct ToneTests {
    /// AlarmKit falls back to the default sound without a word when a Tone's file is missing.
    @Test(arguments: Tone.allCases)
    func everyToneShipsItsFile(tone: Tone) {
        #expect(Bundle.main.url(forResource: tone.fileName, withExtension: nil) != nil)
    }

    /// Alarm Sets saved before Tones existed have no "tone", and ring the default sound, as does a Tone that no longer ships.
    @Test(arguments: [
        (#"[{"hour":5,"minute":10}]"#, [Alarm(time: AlarmTime(hour: 5, minute: 10), tone: nil)]),
        (#"[{"hour":5,"minute":10,"tone":"alarm-clock"}]"#, [Alarm(time: AlarmTime(hour: 5, minute: 10), tone: .alarmClock)]),
        (#"[{"hour":5,"minute":10,"tone":"gong"}]"#, [Alarm(time: AlarmTime(hour: 5, minute: 10), tone: nil)]),
    ])
    func decodesASavedAlarmSet(json: String, expected: [Alarm]) throws {
        #expect(try JSONDecoder().decode([Alarm].self, from: Data(json.utf8)) == expected)
    }

    @Test(arguments: [nil, Tone.birdsong])
    func anAlarmSurvivesBeingSaved(tone: Tone?) throws {
        let alarm = Alarm(time: AlarmTime(hour: 18, minute: 30), tone: tone)

        #expect(try JSONDecoder().decode(Alarm.self, from: JSONEncoder().encode(alarm)) == alarm)
    }
}
