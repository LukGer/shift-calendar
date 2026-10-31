import SwiftData
import SwiftUI

/// Whether Arming may read her calendar, set alarms and warn her, and when it last armed.
struct ArmingStatusSection: View {
    let notificationPermission: NotificationPermission?
    @Query private var records: [ArmingRecord]
    /// Changes when a permission prompt closes and when she comes back from the Settings app, so the rows read again.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section("Status") {
            LabeledContent("Calendar access", value: EventKitCalendarStore().hasFullAccess ? "Allowed" : "Not allowed")
            LabeledContent("Alarms", value: AlarmKitScheduler().isAuthorized ? "Allowed" : "Not allowed")
            LabeledContent("Notifications", value: notificationsValue)
            LabeledContent("Last armed") {
                if let lastArmed = records.first?.lastArmed {
                    Text(lastArmed, format: .relative(presentation: .named))
                } else {
                    Text("Never")
                }
            }
        }
    }

    private var notificationsValue: String {
        switch notificationPermission {
        case .allowed: "Allowed"
        case .notAsked: "Not asked"
        case .denied: "Off"
        case nil: ""
        }
    }
}
