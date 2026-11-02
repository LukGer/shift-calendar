import SwiftUI

/// The diagonal stripes that mark a Skipped Shift. They sweep in from the leading edge as `progress` goes from 0 to 1.
struct Hatching: Shape {
    var progress: CGFloat = 1
    var spacing: CGFloat = 6

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = rect.minX - rect.height
        let end = start + (rect.maxX - start) * progress
        var x = start
        while x < end {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}
