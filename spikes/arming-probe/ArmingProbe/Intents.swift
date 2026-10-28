import AppIntents

/// Runs when the system Stop control dismisses a probe alarm.
struct ArmOnStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arm on stop"

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        await ArmingProbe.run(trigger: "stopIntent", alarmID: alarmID)
        return .result()
    }
}

/// Runs when the "Arm" secondary button on a probe alarm is tapped.
struct ArmOnSecondaryIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arm on secondary button"

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        await ArmingProbe.run(trigger: "secondaryIntent", alarmID: alarmID)
        return .result()
    }
}
