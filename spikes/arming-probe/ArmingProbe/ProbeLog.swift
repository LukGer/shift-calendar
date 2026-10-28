import Foundation
import os

/// Appends timestamped lines to a file in the app container, so runs that happen
/// while the phone is locked can be read back later. Mirrors every line to the
/// unified log (Console.app, subsystem "ArmingProbe") in case the file write fails.
enum ProbeLog {
    private static let logger = Logger(subsystem: "ArmingProbe", category: "probe")
    private static let lock = NSLock()
    private static let url = URL.documentsDirectory.appending(path: "probe.log")
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        lock.withLock {
            let data = Data("\(formatter.string(from: .now)) \(message)\n".utf8)
            do {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } else {
                    try data.write(to: url, options: .completeFileProtectionUntilFirstUserAuthentication)
                }
            } catch {
                logger.error("log file write failed: \(error, privacy: .public)")
            }
        }
    }

    static func read() -> String {
        lock.withLock { (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    }

    static func clear() {
        lock.withLock { try? FileManager.default.removeItem(at: url) }
    }
}
