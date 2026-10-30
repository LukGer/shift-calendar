import Foundation
import Testing

struct AppIdentityTests {
    @Test(arguments: [
        ("CFBundleIdentifier", "dev.lukger.shiftalarm"),
        ("CFBundleDisplayName", "Shift Alarm"),
        ("MinimumOSVersion", "26.0"),
        ("NSCalendarsFullAccessUsageDescription", "Shift Alarm finds your Shifts in the calendars you choose. It never changes your calendar."),
        ("NSAlarmKitUsageDescription", "Shift Alarm rings the alarms for your Shifts, even in silent mode and Focus."),
    ])
    func infoPlistValue(key: String, expected: String) {
        #expect(Bundle.main.object(forInfoDictionaryKey: key) as? String == expected)
    }

    @Test func runsOnIPhoneOnly() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] == [1])
    }
}
