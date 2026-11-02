import SwiftData
import SwiftUI

/// Adds a Shift Type, starting from `newShortcut`, when `shiftType` is nil; otherwise edits it.
struct ShiftTypeEditor: View {
    let shiftType: ShiftType?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query private var shiftTypes: [ShiftType]
    @State private var name: String
    @State private var shortcut: String
    @State private var alarms: [EditableAlarm]
    @State private var pickedColorIndex: Int?
    @State private var addedAlarmID: UUID?

    init(shiftType: ShiftType?, newShortcut: String = "") {
        self.shiftType = shiftType
        _name = State(initialValue: shiftType?.name ?? "")
        _shortcut = State(initialValue: shiftType?.shortcut ?? newShortcut)
        _alarms = State(initialValue: (shiftType?.alarmSet ?? []).map { EditableAlarm($0) })
        _pickedColorIndex = State(initialValue: shiftType?.colorIndex)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                LabeledContent("Shortcut") {
                    TextField("td", text: $shortcut)
                        .multilineTextAlignment(.trailing)
                        .monospaced()
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } footer: {
                shortcutFooter
            }

            Section("Colour") {
                ColorSwatches(selection: colorIndex)
            }

            Section {
                ForEach(alarms) { row in
                    NavigationLink {
                        alarmEditor(for: row.id)
                    } label: {
                        LabeledContent {
                            Text(row.alarm.tone.name)
                        } label: {
                            Text(row.alarm.time.text)
                                .monospacedDigit()
                        }
                    }
                }
                .onDelete { alarms.remove(atOffsets: $0) }
                Button("Add Alarm", systemImage: "plus", action: addAlarm)
                    .disabled(alarms.last?.alarm.time == .lastOfDay)
            } header: {
                Text("Alarm Set")
            } footer: {
                if let sharedTime {
                    Text("Two alarms ring at \(sharedTime.text).")
                        .foregroundStyle(.red)
                } else {
                    Text("Rings on the Shift's date. Leave empty to ring nothing.")
                }
            }

            if let shiftType {
                Section {
                    Button("Delete Shift Type", role: .destructive) { delete(shiftType) }
                }
            }
        }
        .navigationTitle(name.trimmed.isEmpty ? String(localized: "New Shift Type") : name.trimmed)
        .navigationDestination(item: $addedAlarmID) { alarmEditor(for: $0) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmed.isEmpty || shortcut.trimmed.isEmpty || isShortcutTaken || sharedTime != nil)
            }
        }
    }

    @ViewBuilder private var shortcutFooter: some View {
        if isShortcutTaken {
            Text("Another Shift Type already uses “\(shortcut.trimmed)”.")
                .foregroundStyle(.red)
        } else if !shortcut.trimmed.isEmpty && name.trimmed.isEmpty {
            Text("All-day events titled “\(shortcut.trimmed)”, in any case, in your chosen calendars become these Shifts.")
        } else if !shortcut.trimmed.isEmpty {
            Text("All-day events titled “\(shortcut.trimmed)”, in any case, in your chosen calendars become \(name.trimmed) Shifts.")
        }
    }

    /// A new Shift Type shows the palette's next colour until she picks one.
    private var colorIndex: Binding<Int> {
        Binding { pickedColorIndex ?? shiftTypes.nextColorIndex } set: { pickedColorIndex = $0 }
    }

    /// A time two alarms share, which would ring only one of their Tones.
    private var sharedTime: AlarmTime? {
        zip(alarms, alarms.dropFirst()).first { $0.alarm.time == $1.alarm.time }?.0.alarm.time
    }

    /// A new alarm rings 10 minutes after the last one, on the default sound, and opens at once.
    private func addAlarm() {
        let time = alarms.last?.alarm.time.adding(minutes: 10) ?? AlarmTime(hour: 6, minute: 0)
        let added = EditableAlarm(Alarm(time: time, tone: nil))
        withAnimation {
            alarms.append(added)
        }
        addedAlarmID = added.id
    }

    /// Edits the alarm by its identity, and keeps the Alarm Set in time order as its time changes.
    private func alarmEditor(for id: UUID) -> AlarmEditor {
        AlarmEditor(alarm: Binding {
            alarms.first { $0.id == id }!.alarm
        } set: { alarm in
            guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
            alarms[index].alarm = alarm
            alarms.sort { $0.alarm.time < $1.alarm.time }
        })
    }

    private var isShortcutTaken: Bool {
        shiftTypes.contains {
            $0.id != shiftType?.id && $0.shortcut.trimmedAndLowercased == shortcut.trimmedAndLowercased
        }
    }

    private func save() {
        let alarmSet = alarms.map(\.alarm)
        if let shiftType {
            shiftType.name = name.trimmed
            shiftType.shortcut = shortcut
            shiftType.replaceAlarmSet(with: alarmSet)
            shiftType.colorIndex = colorIndex.wrappedValue
        } else {
            _ = try? context.addShiftType(
                name: name.trimmed, shortcut: shortcut, alarmSet: alarmSet, colorIndex: pickedColorIndex)
        }
        saveAndArm()
    }

    private func delete(_ shiftType: ShiftType) {
        context.delete(shiftType)
        saveAndArm()
    }

    private func saveAndArm() {
        try? context.save()
        Task { await arming.run() }
        dismiss()
    }
}

/// The palette as a row of swatches, with the selected colour checked.
private struct ColorSwatches: View {
    @Binding var selection: Int

    var body: some View {
        HStack {
            ForEach(ShiftType.palette.indices, id: \.self) { index in
                let isSelected = index == selection % ShiftType.palette.count
                Button {
                    selection = index
                } label: {
                    Circle()
                        .fill(ShiftType.palette[index].gradient)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ShiftType.palette[index].description.capitalized)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// One row of the Alarm Set while it's being edited. Its own identity keeps the row steady while its time changes.
private struct EditableAlarm: Identifiable {
    let id = UUID()
    var alarm: Alarm

    init(_ alarm: Alarm) {
        self.alarm = alarm
    }
}

#Preview("Picked colour") {
    let container = try! ModelContainer(for: ShiftType.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let nachtdienst = try! container.mainContext.addShiftType(
        name: "Nachtdienst", shortcut: "nd", alarmSet: [Alarm(time: AlarmTime(hour: 18, minute: 30), tone: .cheerful)], colorIndex: 5)
    NavigationStack {
        ShiftTypeEditor(shiftType: nachtdienst)
    }
    .modelContainer(container)
    .environment(Arming.shared)
}

#Preview("New Shift Type gets the next colour") {
    let container = try! ModelContainer(for: ShiftType.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let _ = try! container.mainContext.addShiftType(name: "Tagdienst", shortcut: "td")
    NavigationStack {
        ShiftTypeEditor(shiftType: nil, newShortcut: "nd")
    }
    .modelContainer(container)
    .environment(Arming.shared)
}
