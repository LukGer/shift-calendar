import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView(
            "Shift Alarm",
            systemImage: "alarm",
            description: Text("Your Shifts will show up here.")
        )
    }
}

#Preview {
    ContentView()
}
