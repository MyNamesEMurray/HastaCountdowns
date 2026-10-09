import SwiftUI

struct RepeatRuleEditorView: View {
    @Binding var rule: RepeatRule
    let date: Date

    private var calendar: Calendar { .current }

    private var frequency: Binding<RepeatRule.Frequency> {
        Binding(
            get: { rule.frequency ?? .weekly },
            set: { rule = RepeatRule(frequency: $0, interval: rule.interval) }
        )
    }

    private var dateWeekday: Int { calendar.component(.weekday, from: date) }

    private var selectedWeekdays: Set<Int> {
        rule.weekdays.isEmpty ? [dateWeekday] : rule.weekdays
    }

    private var usesOrdinal: Binding<Bool> {
        Binding(
            get: { rule.ordinalWeekday != nil },
            set: { isOn in
                rule.ordinalWeekday = isOn
                    ? RepeatRule.OrdinalWeekday(ordinal: min(4, (calendar.component(.day, from: date) - 1) / 7 + 1), weekday: dateWeekday)
                    : nil
            }
        )
    }

    private var ordinal: Binding<Int> {
        Binding(
            get: { rule.ordinalWeekday?.ordinal ?? 1 },
            set: { rule.ordinalWeekday?.ordinal = $0 }
        )
    }

    private var ordinalWeekday: Binding<Int> {
        Binding(
            get: { rule.ordinalWeekday?.weekday ?? dateWeekday },
            set: { rule.ordinalWeekday?.weekday = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Frequency", selection: frequency) {
                    ForEach(RepeatRule.Frequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                Stepper(value: $rule.interval, in: 1...99) {
                    LabeledContent("Every", value: frequency.wrappedValue.unit.duration(rule.interval))
                }
            } footer: {
                Text(rule.sentence)
            }

            if rule.frequency == .weekly {
                Section("On") {
                    HStack(spacing: 6) {
                        ForEach(RepeatRule.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                            weekdayButton(weekday)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if rule.frequency == .monthly {
                Section {
                    Picker("Monthly", selection: usesOrdinal) {
                        Text("repeat.onDay \(calendar.component(.day, from: date))").tag(false)
                        Text("On the…").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if rule.ordinalWeekday != nil {
                        HStack(spacing: 0) {
                            Picker("Week", selection: ordinal) {
                                ForEach(RepeatRule.OrdinalWeekday.ordinals, id: \.self) { ordinal in
                                    Text(RepeatRule.OrdinalWeekday.title(for: ordinal)).tag(ordinal)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Weekday", selection: ordinalWeekday) {
                                ForEach(RepeatRule.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                                    Text(calendar.weekdaySymbols[weekday - 1]).tag(weekday)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                        .labelsHidden()
                        .frame(height: 150)
                    }
                }
            }
        }
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if rule.frequency == nil { rule = .weekly }
        }
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let isSelected = selectedWeekdays.contains(weekday)
        return Button {
            var days = selectedWeekdays
            if isSelected { days.remove(weekday) } else { days.insert(weekday) }
            guard !days.isEmpty else { return }
            rule.weekdays = days == [dateWeekday] ? [] : days
        } label: {
            Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
