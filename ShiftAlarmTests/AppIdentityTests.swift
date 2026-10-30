import Foundation
import Testing

struct AppIdentityTests {
    @Test(arguments: [
        ("CFBundleIdentifier", "dev.lukger.shiftalarm"),
        ("CFBundleDisplayName", "Shift Alarm"),
        ("MinimumOSVersion", "26.0"),
    ])
    func infoPlistValue(key: String, expected: String) {
        #expect(Bundle.main.object(forInfoDictionaryKey: key) as? String == expected)
    }

    @Test func runsOnIPhoneOnly() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] == [1])
    }
}
