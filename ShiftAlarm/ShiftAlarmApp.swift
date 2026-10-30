import SwiftUI

@main
struct ShiftAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            if let container = try? SharedStore.container() {
                HomeView()
                    .modelContainer(container)
                    .environment(Arming.shared)
            } else {
                ContentUnavailableView(
                    "Shift Alarm can't open its data",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Quit and reopen the app.")
                )
            }
        }
    }
}
