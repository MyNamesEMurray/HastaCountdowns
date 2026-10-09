import EventKit
import SwiftUI

struct CalendarEventPickerView: View {
    let onPick: (Countdown) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("hiddenCalendarIDs") private var hiddenCalendarIDsStorage = ""
    @State private var store = EKEventStore()
    @State private var hasAccess: Bool?
    @State private var events: [EKEvent] = []
    @State private var calendars: [EKCalendar] = []
    @State private var searchText = ""
    @State private var isShowingCalendars = false
    @State private var pendingRepeat: Countdown?

    private var hiddenCalendarIDs: Binding<Set<String>> {
        Binding(
            get: { Set(hiddenCalendarIDsStorage.split(separator: ",").map(String.init)) },
            set: { hiddenCalendarIDsStorage = $0.sorted().joined(separator: ",") }
        )
    }

    private var visibleEvents: [EKEvent] {
        let hidden = hiddenCalendarIDs.wrappedValue
        return events.filter { event in
            !hidden.contains(event.calendar.calendarIdentifier)
                && (searchText.isEmpty || (event.title ?? "").localizedCaseInsensitiveContains(searchText))
        }
    }

    private var months: [(start: Date, events: [EKEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEvents) { calendar.dateInterval(of: .month, for: $0.start)?.start ?? $0.start }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Choose Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    if hasAccess == true {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Calendars") { isShowingCalendars = true }
                        }
                    }
                }
                .sheet(isPresented: $isShowingCalendars) {
                    CalendarFilterView(calendars: calendars, hiddenIDs: hiddenCalendarIDs)
                }
                .repeatChoice(for: $pendingRepeat, onChoose: finish)
        }
        .task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            if granted { load() }
            hasAccess = granted
        }
    }

    @ViewBuilder
    private var content: some View {
        switch hasAccess {
        case nil:
            ProgressView()
        case false:
            ContentUnavailableView {
                Label("Calendar Access Needed", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("Allow Hasta to see your calendars in Settings to import an event.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        default:
            List {
                ForEach(months, id: \.start) { month in
                    Section(header(for: month.start)) {
                        ForEach(month.events, id: \.eventIdentifier) { event in
                            row(event)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .overlay {
                if visibleEvents.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("No Upcoming Events", systemImage: "calendar")
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
    }

    private func row(_ event: EKEvent) -> some View {
        Button {
            let countdown = Countdown(event: event)
            if countdown.repeatRule.frequency == nil {
                finish(countdown)
            } else {
                pendingRepeat = countdown
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "")
                        .foregroundStyle(.primary)
                    Text(detail(for: event))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func header(for month: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(month, equalTo: .now, toGranularity: .month) {
            return String(localized: "This Month")
        }
        if calendar.isDate(month, equalTo: .now, toGranularity: .year) {
            return month.formatted(.dateTime.month(.wide))
        }
        return month.formatted(.dateTime.month(.wide).year())
    }

    private func detail(for event: EKEvent) -> String {
        var parts = [event.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())]
        parts.append(event.isAllDay ? String(localized: "All-Day") : event.start.formatted(date: .omitted, time: .shortened))
        let rule = Countdown(event: event).repeatRule
        if rule.frequency != nil {
            parts.append(rule.title)
        }
        return parts.joined(separator: " · ")
    }

    private func load() {
        calendars = store.calendars(for: .event)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .year, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var seen = Set<String>()
        events = store.events(matching: predicate)
            .sorted { $0.start < $1.start }
            .filter { seen.insert($0.eventIdentifier ?? UUID().uuidString).inserted }
    }

    private func finish(_ countdown: Countdown) {
        onPick(countdown)
        dismiss()
    }
}

private struct CalendarFilterView: View {
    let calendars: [EKCalendar]
    @Binding var hiddenIDs: Set<String>
    @Environment(\.dismiss) private var dismiss

    private var sources: [(title: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: calendars) { $0.source.title }
        return grouped.keys.sorted().map { ($0, grouped[$0]?.sorted { $0.title < $1.title } ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sources, id: \.title) { source in
                    Section(source.title) {
                        ForEach(source.calendars, id: \.calendarIdentifier) { calendar in
                            let isVisible = !hiddenIDs.contains(calendar.calendarIdentifier)
                            Button {
                                if isVisible {
                                    hiddenIDs.insert(calendar.calendarIdentifier)
                                } else {
                                    hiddenIDs.remove(calendar.calendarIdentifier)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.tint)
                                        .opacity(isVisible ? 1 : 0)
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .accessibilityAddTraits(isVisible ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Show All") { hiddenIDs = [] }
                        .disabled(hiddenIDs.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension Countdown {
    init(event: EKEvent, calendar: Calendar = .current) {
        let rule = event.recurrenceRules?.first.map { rule in
            RepeatRule(
                frequency: RepeatRule.Frequency(rule.frequency),
                interval: rule.interval,
                days: (rule.daysOfTheWeek ?? []).map { ($0.weekNumber == 0 ? nil : $0.weekNumber, $0.dayOfTheWeek.rawValue) },
                position: rule.setPositions?.first?.intValue
            ).normalized(for: event.start, calendar: calendar)
        }
        self.init(
            title: event.title ?? "",
            date: event.start,
            isAllDay: event.isAllDay,
            timeZoneIdentifier: event.isAllDay ? calendar.timeZone.identifier : (event.timeZone ?? calendar.timeZone).identifier,
            repeatRule: rule ?? .never
        )
    }
}

private extension RepeatRule.Frequency {
    init(_ frequency: EKRecurrenceFrequency) {
        switch frequency {
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .monthly: self = .monthly
        case .yearly: self = .yearly
        @unknown default: self = .yearly
        }
    }
}

private extension EKEvent {
    var start: Date { startDate ?? .now }
}
