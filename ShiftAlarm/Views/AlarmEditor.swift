import SwiftUI

/// When one alarm of an Alarm Set rings, and with which Tone. Tapping a Tone plays it.
struct AlarmEditor: View {
    @Binding var alarm: Alarm
    @State private var player = TonePlayer()

    var body: some View {
        Form {
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            Section("Tone") {
                toneRow(nil)
                ForEach(Tone.allCases, id: \.self) { toneRow($0) }
            }
        }
        .navigationTitle("Alarm")
        .onDisappear { player.stop() }
    }

    private var time: Binding<Date> {
        Binding {
            alarm.time.instant(on: .now, calendar: .current)
        } set: {
            alarm.time = AlarmTime(of: $0, calendar: .current)
        }
    }

    private func toneRow(_ tone: Tone?) -> some View {
        Button {
            alarm.tone = tone
            player.play(tone)
        } label: {
            LabeledContent {
                if alarm.tone == tone {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            } label: {
                Text(tone.name)
                    .foregroundStyle(Color.primary)
            }
        }
        .accessibilityAddTraits(alarm.tone == tone ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var alarm = Alarm(time: AlarmTime(hour: 5, minute: 0), tone: .kalimba)
    NavigationStack {
        AlarmEditor(alarm: $alarm)
    }
}
