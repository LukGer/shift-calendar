import SwiftData
import SwiftUI

/// Whether Arming may read her calendar, set alarms and warn her, and when it last armed.
struct ArmingStatusSection: View {
    @Query private var records: [ArmingRecord]
    /// Changes when a permission prompt closes and when she comes back from the Settings app.
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationsAllowed = false

    var body: some View {
        Section("Status") {
            LabeledContent("Calendar access", value: EventKitReader().hasFullAccess ? "Allowed" : "Not allowed")
            LabeledContent("Alarms", value: AlarmKitScheduler().isAuthorized ? "Allowed" : "Not allowed")
            LabeledContent("Notifications", value: notificationsAllowed ? "Allowed" : "Off")
            LabeledContent("Last armed") {
                if let lastArmed = records.first?.lastArmed {
                    Text(lastArmed, format: .relative(presentation: .named))
                } else {
                    Text("Never")
                }
            }
        }
        .task(id: scenePhase) {
            notificationsAllowed = await UserNotificationsNotifier().isAuthorized()
        }
    }
}
