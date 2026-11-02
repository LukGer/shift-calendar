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
            LabeledContent("Calendar access", value: allowed(EventKitCalendarStore().hasFullAccess))
            LabeledContent("Alarms", value: allowed(AlarmKitScheduler().isAuthorized))
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

    private func allowed(_ isAllowed: Bool) -> String {
        isAllowed ? String(localized: "Allowed") : String(localized: "Not allowed")
    }

    private var notificationsValue: String {
        switch notificationPermission {
        case .allowed: allowed(true)
        case .notAsked: String(localized: "Not asked")
        case .denied: String(localized: "Off")
        case nil: ""
        }
    }
}
