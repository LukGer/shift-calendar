import AppIntents

/// Runs Arming in the background, without opening the app: every alarm's Stop runs it, and so does the "Arm Shifts" App Shortcut.
/// AlarmKit only accepts a LiveActivityIntent as an alarm's stop intent.
struct ArmShiftsIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arm Shifts"
    static let description = IntentDescription("Arms the alarms for your upcoming Shifts.")

    func perform() async throws -> some IntentResult {
        await Arming.shared.run()
        return .result()
    }
}

struct ShiftAlarmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ArmShiftsIntent(),
            phrases: ["Arm Shifts in \(.applicationName)"],
            shortTitle: "Arm Shifts",
            systemImageName: "alarm"
        )
    }
}
