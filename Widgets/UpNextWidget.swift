import SwiftUI
import WidgetKit

struct UpNextEntry: TimelineEntry {
    let date: Date
    let countdowns: [Countdown]
}

struct UpNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry {
        UpNextEntry(date: .now, countdowns: Countdown.samples.upcoming())
    }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        let all = CountdownRepository.load()
        if all.isEmpty && context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(entry(at: .now, countdowns: all))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let all = CountdownRepository.load()
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        var dates: Set<Date> = [now]
        for offset in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                dates.insert(midnight)
            }
        }
        for countdown in all where !countdown.isAllDay {
            dates.formUnion(WidgetRefreshSchedule.closeRangeDates(for: countdown, now: now))
        }
        let entries = dates.sorted().prefix(240).map { entry(at: $0, countdowns: all) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, countdowns: [Countdown]) -> UpNextEntry {
        let isPremium = Premium.isUnlocked
        let upcoming = countdowns.map { $0.resolved(isPremium: isPremium) }.upcoming(at: date)
        return UpNextEntry(date: date, countdowns: upcoming)
    }
}

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpNextEntry

    var body: some View {
        if family == .accessoryRectangular {
            UpNextAccessoryView(countdowns: entry.countdowns, now: entry.date)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(entry.countdowns.isEmpty ? DeepLink.newCountdown : nil)
        } else {
            UpNextView(countdowns: entry.countdowns, now: entry.date, limit: family == .systemLarge ? 6 : 3)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
                .widgetURL(entry.countdowns.isEmpty ? DeepLink.newCountdown : nil)
        }
    }
}

struct UpNextWidget: Widget {
    static let kind = "UpNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: UpNextProvider()) { entry in
            UpNextWidgetView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("See your next few countdowns at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

#Preview("Up Next", as: .systemMedium) {
    UpNextWidget()
} timeline: {
    UpNextEntry(date: .now, countdowns: Countdown.samples.upcoming())
}

#Preview("Up Next Lock Screen", as: .accessoryRectangular) {
    UpNextWidget()
} timeline: {
    UpNextEntry(date: .now, countdowns: Countdown.samples.upcoming())
}
