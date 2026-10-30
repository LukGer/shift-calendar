import SwiftData
import SwiftUI

/// Whether Arming may read her calendar and set alarms, and when it last armed.
struct ArmingStatusSection: View {
    @Query private var records: [ArmingRecord]

    var body: some View {
        Section("Status") {
            LabeledContent("Calendar access", value: EventKitReader().hasFullAccess ? "Allowed" : "Not allowed")
            LabeledContent("Alarms", value: AlarmKitScheduler().isAuthorized ? "Allowed" : "Not allowed")
            LabeledContent("Last armed") {
                if let lastArmed = records.first?.lastArmed {
                    Text(lastArmed, format: .relative(presentation: .named))
                } else {
                    Text("Never")
                }
            }
        }
    }
}
