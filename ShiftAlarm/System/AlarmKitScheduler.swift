import AlarmKit
import SwiftUI

/// Arms one-shot AlarmKit alarms: titled with the Shift Type's name, tinted with its colour,
/// with the default sound and only a Stop button.
struct AlarmKitScheduler: AlarmScheduler {
    private var manager: AlarmManager { .shared }

    func alarmIDs() throws -> Set<UUID> {
        Set(try manager.alarms.map(\.id))
    }

    func schedule(_ alarm: WantedAlarm) async throws {
        if manager.authorizationState == .notDetermined {
            _ = try await manager.requestAuthorization()
        }
        // The stopButton initializer is the one available on iOS 26.0; from 26.1 the system ignores the button.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes<ShiftAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: alarm.tint
        )
        _ = try await manager.schedule(
            id: alarm.id,
            configuration: .alarm(schedule: .fixed(alarm.instant), attributes: attributes)
        )
    }

    func cancel(id: UUID) throws {
        try manager.cancel(id: id)
    }
}

nonisolated struct ShiftAlarmMetadata: AlarmMetadata {}
