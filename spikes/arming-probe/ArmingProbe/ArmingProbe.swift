import AlarmKit
import EventKit
import SwiftUI

struct ProbeMetadata: AlarmMetadata {}

typealias ProbeConfiguration = AlarmManager.AlarmConfiguration<ProbeMetadata>

/// What a real Arming run would do, instrumented: read the next week of calendar
/// events, then replace a batch of alarms, then stay alive to see how long iOS lets it.
enum ArmingProbe {
    static let windowDays = 7
    static let reconcileAlarmCount = 20
    static let heartbeatSeconds = 60
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

    private static let manager = AlarmManager.shared
    private static let defaults = UserDefaults.standard

    // MARK: Locked-stop test

    static func run(trigger: String, alarmID: String) async {
        let started = Date.now
        func log(_ message: String) {
            ProbeLog.write("[\(trigger) +\(String(format: "%.1f", Date.now.timeIntervalSince(started)))s] \(message)")
        }

        let app = await MainActor.run {
            "protectedData=\(UIApplication.shared.isProtectedDataAvailable) appState=\(describe(UIApplication.shared.applicationState)) bgRefresh=\(describe(UIApplication.shared.backgroundRefreshStatus))"
        }
        log("start alarm=\(alarmID.prefix(8)) build=\(build) \(app) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        log(readCalendar())
        log(await replaceReconcileAlarms())
        if defaults.bool(forKey: "chain") {
            log(await scheduleTestAlarm(inMinutes: defaults.integer(forKey: "chainMinutes")))
        }
        for _ in stride(from: 0, to: heartbeatSeconds, by: 5) {
            try? await Task.sleep(for: .seconds(5))
            log("alive")
        }
        log("end")
    }

    static func readCalendar() -> String {
        let store = EKEventStore()
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: windowDays, to: start)!
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        let allDayTitles = events.filter(\.isAllDay).map { $0.title ?? "?" }
        return "calendar status=\(describe(EKEventStore.authorizationStatus(for: .event))) calendars=\(store.calendars(for: .event).count) events=\(events.count) allDay=\(allDayTitles)"
    }

    /// Stands in for a reconcile: cancel last run's alarms, schedule a fresh batch far enough out not to ring.
    static func replaceReconcileAlarms() async -> String {
        let base = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        do {
            let before = try manager.alarms.count
            cancel(storedIDs: "reconcileIDs")
            var ids: [UUID] = []
            for index in 0..<reconcileAlarmCount {
                let id = UUID()
                _ = try await schedule(id: id, at: base.addingTimeInterval(Double(index) * 600), title: "Probe reconcile \(index)")
                ids.append(id)
            }
            store(ids, as: "reconcileIDs")
            return "alarmkit auth=\(manager.authorizationState) before=\(before) after=\(try manager.alarms.count)"
        } catch {
            return "alarmkit error \(error)"
        }
    }

    static func scheduleTestAlarm(inMinutes minutes: Int) async -> String {
        let id = UUID()
        let fireDate = Date.now.addingTimeInterval(Double(minutes) * 60)
        let time = fireDate.formatted(date: .omitted, time: .standard)
        do {
            _ = try await manager.schedule(id: id, configuration: .alarm(
                schedule: .fixed(fireDate),
                attributes: attributes(
                    title: "Probe \(time)",
                    secondaryButton: AlarmButton(text: "Arm", textColor: .white, systemImageName: "arrow.clockwise")
                ),
                stopIntent: ArmOnStopIntent(alarmID: id.uuidString),
                secondaryIntent: ArmOnSecondaryIntent(alarmID: id.uuidString)
            ))
            return "test alarm \(id.uuidString.prefix(8)) rings at \(time)"
        } catch {
            return "test alarm error \(error)"
        }
    }

    // MARK: Secondary experiments

    static func findAlarmLimit() async -> String {
        let base = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
        var ids: [UUID] = []
        defer { ids.forEach { try? manager.cancel(id: $0) } }
        do {
            while ids.count < 1000 {
                let id = UUID()
                _ = try await schedule(id: id, at: base.addingTimeInterval(Double(ids.count) * 60), title: "Probe limit")
                ids.append(id)
            }
            return "limit: 1000 new alarms scheduled without error, total=\((try? manager.alarms.count) ?? -1); all cancelled"
        } catch {
            return "limit: \(error) after \(ids.count) new alarms, total=\((try? manager.alarms.count) ?? -1); new ones cancelled"
        }
    }

    static func scheduleSentinels() async -> String {
        cancel(storedIDs: "sentinelIDs")
        let base = Calendar.current.date(byAdding: .day, value: 30, to: .now)!.addingTimeInterval(3600)
        do {
            var ids: [UUID] = []
            for index in 0..<3 {
                let id = UUID()
                _ = try await schedule(id: id, at: base.addingTimeInterval(Double(index) * 60), title: "Probe sentinel \(index)")
                ids.append(id)
            }
            store(ids, as: "sentinelIDs")
            defaults.set(build, forKey: "sentinelBuild")
            return "sentinels: scheduled 3 by build \(build)"
        } catch {
            return "sentinels error \(error)"
        }
    }

    static func sentinelReport() -> String {
        let sentinels = storedIDs("sentinelIDs")
        guard !sentinels.isEmpty else { return "sentinels: none scheduled" }
        let present = Set((try? manager.alarms.map(\.id)) ?? [])
        return "sentinels: \(sentinels.filter(present.contains).count)/\(sentinels.count) present, scheduled by build \(defaults.string(forKey: "sentinelBuild") ?? "?"), running build \(build)"
    }

    static func scheduleExistingIDTwice() async -> String {
        let id = UUID()
        let first = Calendar.current.date(byAdding: .day, value: 40, to: .now)!
        defer { try? manager.cancel(id: id) }
        do {
            _ = try await schedule(id: id, at: first, title: "Probe existing ID")
        } catch {
            return "existing id: first schedule failed \(error)"
        }
        var outcome: String
        do {
            let alarm = try await schedule(id: id, at: first.addingTimeInterval(86_400), title: "Probe existing ID again")
            outcome = "second schedule succeeded, returned \(String(describing: alarm.schedule))"
        } catch {
            outcome = "second schedule threw \(error)"
        }
        let listed = ((try? manager.alarms) ?? []).filter { $0.id == id }.map { String(describing: $0.schedule) }
        return "existing id: \(outcome); listed with that id: \(listed)"
    }

    static func cancelAll() -> String {
        let alarms = (try? manager.alarms) ?? []
        alarms.forEach { try? manager.cancel(id: $0.id) }
        ["reconcileIDs", "sentinelIDs"].forEach { defaults.removeObject(forKey: $0) }
        return "cancelled \(alarms.count) alarms"
    }

    // MARK: Status

    static func calendarStatus() -> String { describe(EKEventStore.authorizationStatus(for: .event)) }
    static func alarmStatus() -> String { "\(manager.authorizationState)" }

    static func requestAccess() async -> String {
        do {
            let calendar = try await EKEventStore().requestFullAccessToEvents()
            let alarms = try await manager.requestAuthorization()
            return "access: calendar granted=\(calendar) alarms=\(alarms)"
        } catch {
            return "access request error \(error)"
        }
    }

    // MARK: Helpers

    private static func schedule(id: UUID, at date: Date, title: LocalizedStringResource) async throws -> Alarm {
        try await manager.schedule(id: id, configuration: ProbeConfiguration.alarm(schedule: .fixed(date), attributes: attributes(title: title)))
    }

    private static func attributes(title: LocalizedStringResource, secondaryButton: AlarmButton? = nil) -> AlarmAttributes<ProbeMetadata> {
        let alert = AlarmPresentation.Alert(
            title: title,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButton == nil ? nil : .custom
        )
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert), tintColor: .orange)
    }

    private static func storedIDs(_ key: String) -> [UUID] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:))
    }

    private static func store(_ ids: [UUID], as key: String) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }

    private static func cancel(storedIDs key: String) {
        storedIDs(key).forEach { try? manager.cancel(id: $0) }
    }

    private static func describe(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .fullAccess: "fullAccess"
        case .writeOnly: "writeOnly"
        @unknown default: "unknown(\(status.rawValue))"
        }
    }

    private static func describe(_ state: UIApplication.State) -> String {
        switch state {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown(\(state.rawValue))"
        }
    }

    private static func describe(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available: "available"
        case .denied: "denied"
        case .restricted: "restricted"
        @unknown default: "unknown(\(status.rawValue))"
        }
    }
}
