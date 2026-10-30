import Testing
import UserNotifications
@testable import ShiftAlarm

/// The home banner warns only when she has denied notifications; Settings asks her when she hasn't been asked yet.
struct NotificationPermissionTests {
    @Test(arguments: [
        (UNAuthorizationStatus.authorized, NotificationPermission.allowed),
        (.provisional, .allowed),
        (.ephemeral, .allowed),
        (.notDetermined, .notAsked),
        (.denied, .denied),
    ])
    func onlyADenialCountsAsDenied(status: UNAuthorizationStatus, expected: NotificationPermission) {
        #expect(NotificationPermission(status) == expected)
    }
}
