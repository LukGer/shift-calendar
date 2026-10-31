import SwiftUI

struct SkipButton: View {
    let isSkipped: Bool
    let toggleSkip: () -> Void

    var body: some View {
        Button(
            isSkipped ? "Ring for this Shift" : "Skip this Shift",
            systemImage: isSkipped ? "bell" : "moon.zzz",
            action: toggleSkip
        )
    }
}
