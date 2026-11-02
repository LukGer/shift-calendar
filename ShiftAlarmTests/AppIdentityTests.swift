import Foundation
import Testing
@testable import ShiftAlarm

struct AppIdentityTests {
    @Test(arguments: [
        ("CFBundleIdentifier", "dev.lukger.shiftalarm"),
        ("CFBundleDisplayName", "Kathlender"),
        ("MinimumOSVersion", "26.0"),
        ("NSCalendarsFullAccessUsageDescription", "Kathlender finds your Shifts in the calendars you choose. It only writes to your calendar when you plan a Shift."),
        ("NSAlarmKitUsageDescription", "Kathlender rings the alarms for your Shifts, even in silent mode and Focus."),
    ])
    func infoPlistValue(key: String, expected: String) {
        #expect(Bundle.main.infoDictionary?[key] as? String == expected)
    }

    @Test(arguments: [
        ("BGTaskSchedulerPermittedIdentifiers", [BackgroundRefresh.identifier]),
        ("UIBackgroundModes", ["fetch"]),
    ])
    func infoPlistList(key: String, expected: [String]) {
        #expect(Bundle.main.object(forInfoDictionaryKey: key) as? [String] == expected)
    }

    @Test func runsOnIPhoneOnly() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] == [1])
    }
}
