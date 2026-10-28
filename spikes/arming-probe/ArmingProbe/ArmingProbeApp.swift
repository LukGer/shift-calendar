import SwiftUI

@main
struct ArmingProbeApp: App {
    init() {
        UserDefaults.standard.register(defaults: ["chain": true, "chainMinutes": 2])
        ProbeLog.write("launch build=\(ArmingProbe.build) \(ArmingProbe.sentinelReport())")
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @AppStorage("chain") private var chain = true
    @AppStorage("chainMinutes") private var chainMinutes = 2
    @State private var minutes = 1
    @State private var log = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Permissions") {
                    LabeledContent("Calendar", value: ArmingProbe.calendarStatus())
                    LabeledContent("Alarms", value: ArmingProbe.alarmStatus())
                    Button("Request access") { perform { await ArmingProbe.requestAccess() } }
                }
                Section {
                    Stepper("Ring in \(minutes) min", value: $minutes, in: 1...10)
                    Button("Schedule test alarm") { perform { await ArmingProbe.scheduleTestAlarm(inMinutes: minutes) } }
                    Toggle("Each run schedules another", isOn: $chain)
                    Stepper("…ringing \(chainMinutes) min later", value: $chainMinutes, in: 1...30)
                } header: {
                    Text("Locked-stop test")
                } footer: {
                    Text("Schedule, lock the phone, let it ring, stop it (or tap Arm). Come back and read the log.")
                }
                Section("Experiments") {
                    Button("Find alarm limit") { perform { await ArmingProbe.findAlarmLimit() } }
                    Button("Schedule update sentinels") { perform { await ArmingProbe.scheduleSentinels() } }
                    Text(ArmingProbe.sentinelReport())
                    Button("Schedule an existing ID twice") { perform { await ArmingProbe.scheduleExistingIDTwice() } }
                    Button("Cancel all probe alarms", role: .destructive) { perform { ArmingProbe.cancelAll() } }
                }
                Section("Log, newest first") {
                    Button("Copy log") { UIPasteboard.general.string = ProbeLog.read() }
                    Button("Clear log", role: .destructive) { ProbeLog.clear(); refresh() }
                    Text(log).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
            .navigationTitle("Arming Probe")
            .refreshable { refresh() }
            .onChange(of: scenePhase, initial: true) { refresh() }
        }
    }

    private func perform(_ action: @escaping () async -> String) {
        Task {
            ProbeLog.write("[app] \(await action())")
            refresh()
        }
    }

    private func refresh() {
        log = ProbeLog.read().split(separator: "\n").suffix(300).reversed().joined(separator: "\n")
    }
}
