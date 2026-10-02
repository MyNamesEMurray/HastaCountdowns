import SwiftUI

struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rule: ReminderRule
    @State private var usesCustomTime: Bool
    @State private var time: Date

    let isAllDay: Bool
    let isNew: Bool
    let onSave: (ReminderRule) -> Void
    let onDelete: () -> Void

    init(rule: ReminderRule, isAllDay: Bool, isNew: Bool, onSave: @escaping (ReminderRule) -> Void, onDelete: @escaping () -> Void) {
        _rule = State(initialValue: rule)
        _usesCustomTime = State(initialValue: rule.hour != nil)
        let defaultTime = ReminderPreferences.time
        let components = DateComponents(hour: rule.hour ?? defaultTime.hour ?? 9, minute: rule.minute ?? defaultTime.minute ?? 0)
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
        self.isAllDay = isAllDay
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var units: [ReminderRule.Unit] {
        var available = ReminderRule.Unit.available(isAllDay: isAllDay)
        if !available.contains(rule.unit) {
            available.insert(rule.unit, at: 0)
        }
        return available
    }

    private var result: ReminderRule {
        var updated = rule
        if updated.unit.usesTimeOfDay && usesCustomTime {
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            updated.hour = components.hour
            updated.minute = components.minute
        } else {
            updated.hour = nil
            updated.minute = nil
        }
        return updated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        Picker("Amount", selection: $rule.amount) {
                            ForEach(0...99, id: \.self) { amount in
                                Text("\(amount)").tag(amount)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Unit", selection: $rule.unit) {
                            ForEach(units) { unit in
                                Text(unit.name(for: rule.amount).capitalized).tag(unit)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .labelsHidden()
                    .frame(height: 170)
                } header: {
                    Text("Before the Event")
                } footer: {
                    Text("Choose 0 to be reminded on the day itself.")
                }

                if rule.unit.usesTimeOfDay {
                    Section {
                        Toggle(isAllDay ? "Custom Time" : "Specific Time", isOn: $usesCustomTime.animation())
                        if usesCustomTime {
                            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        }
                    } footer: {
                        if !usesCustomTime {
                            Text(isAllDay
                                 ? "Uses your default reminder time, \(ReminderPreferences.formattedTime)."
                                 : "Arrives at the same time of day as the event.")
                        }
                    }
                }

                Section {
                    Label {
                        Text(result.title(isAllDay: isAllDay, defaultTime: ReminderPreferences.time))
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.tint)
                    }
                } header: {
                    Text("Reminder")
                }

                if !isNew {
                    Section {
                        Button("Delete Reminder", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "Add Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") {
                        onSave(result)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}
