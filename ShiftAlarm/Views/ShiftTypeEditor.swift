import SwiftData
import SwiftUI

/// Adds a Shift Type when `shiftType` is nil, otherwise edits it.
struct ShiftTypeEditor: View {
    let shiftType: ShiftType?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Arming.self) private var arming
    @Query private var shiftTypes: [ShiftType]
    @State private var name: String
    @State private var shortcut: String
    @State private var alarms: [EditableAlarm]

    init(shiftType: ShiftType?) {
        self.shiftType = shiftType
        _name = State(initialValue: shiftType?.name ?? "")
        _shortcut = State(initialValue: shiftType?.shortcut ?? "")
        _alarms = State(initialValue: (shiftType?.alarmSet ?? []).map { EditableAlarm($0) })
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

            Section {
                ForEach($alarms) { $alarm in
                    DatePicker("Alarm", selection: $alarm.time, displayedComponents: .hourAndMinute)
                }
                .onDelete { alarms.remove(atOffsets: $0) }
                Button("Add Alarm", systemImage: "plus") {
                    alarms.append(EditableAlarm(AlarmTime(hour: 6, minute: 0)))
                }
            } header: {
                Text("Alarm Set")
            } footer: {
                Text("Rings on the Shift's date. Leave empty to ring nothing.")
            }

            if let shiftType {
                Section {
                    Button("Delete Shift Type", role: .destructive) { delete(shiftType) }
                }
            }
        }
        .navigationTitle(trimmedName.isEmpty ? "New Shift Type" : trimmedName)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedName.isEmpty || trimmedShortcut.isEmpty || isShortcutTaken)
            }
        }
    }

    @ViewBuilder private var shortcutFooter: some View {
        if isShortcutTaken {
            Text("Another Shift Type already uses “\(trimmedShortcut)”.")
                .foregroundStyle(.red)
        } else if !trimmedShortcut.isEmpty {
            Text("All-day events titled “\(trimmedShortcut)”, in any case, in your chosen calendars become \(trimmedName.isEmpty ? "these" : trimmedName) Shifts.")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedShortcut: String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShortcutTaken: Bool {
        shiftTypes.contains {
            $0.id != shiftType?.id && ShiftType.comparable($0.shortcut) == ShiftType.comparable(shortcut)
        }
    }

    private func save() {
        let alarmSet = alarms.map { AlarmTime(of: $0.time, calendar: .current) }
        if let shiftType {
            shiftType.name = trimmedName
            shiftType.shortcut = shortcut
            shiftType.replaceAlarmSet(with: alarmSet)
        } else {
            let nextColorIndex = (shiftTypes.map(\.colorIndex).max() ?? -1) + 1
            context.insert(ShiftType(name: trimmedName, shortcut: shortcut, alarmSet: alarmSet, colorIndex: nextColorIndex))
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

/// One row of the Alarm Set while it's being edited. Its own identity keeps the row steady while its time changes.
private struct EditableAlarm: Identifiable {
    let id = UUID()
    var time: Date

    init(_ alarmTime: AlarmTime) {
        time = alarmTime.instant(on: .now, calendar: .current)
    }
}
