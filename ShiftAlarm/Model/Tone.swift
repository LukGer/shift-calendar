import Foundation

/// The sound an alarm rings with instead of the default, from gentle to harsh.
/// Each ships as its `fileName`, made by scripts/prepare-tones.py.
nonisolated enum Tone: String, Codable, CaseIterable, Sendable {
    case birdsong, kalimba, cheerful
    case alarmClock = "alarm-clock"

    var name: LocalizedStringResource {
        switch self {
        case .birdsong: "Birdsong"
        case .kalimba: "Kalimba"
        case .cheerful: "Cheerful"
        case .alarmClock: "Alarm Clock"
        }
    }

    var fileName: String {
        "\(rawValue).caf"
    }
}

extension Tone? {
    var name: LocalizedStringResource {
        self?.name ?? "Default"
    }
}
