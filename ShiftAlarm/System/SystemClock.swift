import Foundation

struct SystemClock: WallClock {
    var now: Date { .now }
    var calendar: Calendar { .current }
}
