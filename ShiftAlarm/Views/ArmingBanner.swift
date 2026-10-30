import SwiftUI

/// Tells her why the latest Arming run changed nothing. After a successful run it shows nothing.
struct ArmingBanner: View {
    let outcome: ArmingOutcome?
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch outcome {
        case .skipped(.calendarNotReadable):
            banner(
                "Shift Alarm can't read your calendar", systemImage: "calendar.badge.exclamationmark",
                text: "Your alarms stay as they were. Allow full calendar access in Settings.",
                opensSettings: true)
        case .skipped(.chosenCalendarMissing):
            banner(
                "A chosen calendar can't be found", systemImage: "calendar.badge.exclamationmark",
                text: "Your alarms stay as they were. Choose the calendars that hold your Shifts again.")
        case .skipped(.alarmsNotAllowed):
            banner(
                "Shift Alarm isn't allowed to set alarms", systemImage: "alarm",
                text: "Your alarms stay as they were. Allow alarms in Settings.",
                opensSettings: true)
        case .failed:
            banner(
                "Alarms couldn't be armed", systemImage: "exclamationmark.triangle",
                text: "Alarms already armed still ring. Shift Alarm tries again the next time you open it.")
        case .armed, nil:
            EmptyView()
        }
    }

    private func banner(_ title: String, systemImage: String, text: String, opensSettings: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if opensSettings {
                Button("Open Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.1), in: .rect(cornerRadius: 20))
    }
}

#Preview("Calendar can't be read") {
    ArmingBanner(outcome: .skipped(.calendarNotReadable)).padding()
}

#Preview("Chosen calendar missing") {
    ArmingBanner(outcome: .skipped(.chosenCalendarMissing)).padding()
}

#Preview("Alarms not allowed") {
    ArmingBanner(outcome: .skipped(.alarmsNotAllowed)).padding()
}

#Preview("Failed") {
    ArmingBanner(outcome: .failed).padding()
}
