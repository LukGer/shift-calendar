import BackgroundTasks

/// Asks iOS for a background app refresh that runs Arming. iOS decides when, or whether, it runs.
nonisolated enum BackgroundRefresh {
    static let identifier = "dev.lukger.shiftalarm.arm"

    /// Replaces any pending request.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
