import SwiftUI
import WidgetKit

struct CountdownEntry: TimelineEntry {
    let date: Date
    let countdown: Countdown?
    let upNext: [Countdown]
    let image: UIImage?
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, countdown: Countdown.samples[0], upNext: Array(Countdown.samples.dropFirst()), image: nil)
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        let all = CountdownRepository.load()
        if all.isEmpty && context.isPreview {
            return placeholder(in: context)
        }
        return entry(for: configuration, at: .now, countdowns: all, context: context)
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let all = CountdownRepository.load()
        let now = Date.now
        let calendar = Calendar.current
        var dates: [Date] = [now]
        let startOfToday = calendar.startOfDay(for: now)
        for offset in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                dates.append(midnight)
            }
        }
        if let selected = selectedCountdown(for: configuration, in: all, at: now), !selected.isAllDay {
            let target = selected.nextOccurrence(after: now)
            if target > now, let last = dates.last, target < last {
                dates.append(target)
            }
        }
        dates.sort()

        let image = loadImage(for: selectedCountdown(for: configuration, in: all, at: now), context: context)
        let entries = dates.map { date in
            entry(for: configuration, at: date, countdowns: all, context: context, preloadedImage: image)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func selectedCountdown(for configuration: SelectCountdownIntent, in all: [Countdown], at date: Date) -> Countdown? {
        if let id = configuration.countdown?.id, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.upcoming(at: date).first ?? all.past(at: date).first
    }

    private func entry(
        for configuration: SelectCountdownIntent,
        at date: Date,
        countdowns all: [Countdown],
        context: Context,
        preloadedImage: UIImage?? = nil
    ) -> CountdownEntry {
        let isPremium = Premium.isUnlocked
        let resolvedAll = all.map { $0.resolved(isPremium: isPremium) }
        let selected = selectedCountdown(for: configuration, in: resolvedAll, at: date)
        let upNext = resolvedAll.upcoming(at: date).filter { $0.id != selected?.id }
        let image = preloadedImage ?? loadImage(for: selected, context: context)
        return CountdownEntry(date: date, countdown: selected, upNext: upNext, image: image)
    }

    private func loadImage(for countdown: Countdown?, context: Context) -> UIImage? {
        guard Premium.isUnlocked, let id = countdown?.backgroundImageID else { return nil }
        let size = context.displaySize
        let maxPixel = max(size.width, size.height) * 2.5
        return BackgroundImageStore.image(for: id, maxPixelSize: max(maxPixel, 300))
    }
}

struct CountdownWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        if let countdown = entry.countdown {
            content(for: countdown)
                .widgetURL(DeepLink.countdown(countdown.id))
        } else {
            EmptyCountdownView(compact: family == .accessoryCircular || family == .accessoryInline)
                .widgetURL(DeepLink.newCountdown)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        }
    }

    @ViewBuilder
    private func content(for countdown: Countdown) -> some View {
        let hasImage = entry.image != nil
        switch family {
        case .systemSmall:
            SmallCountdownView(countdown: countdown, now: entry.date, hasImage: hasImage)
                .containerBackground(for: .widget) { CountdownBackground(countdown: countdown, image: entry.image) }
        case .systemMedium:
            MediumCountdownView(countdown: countdown, now: entry.date, hasImage: hasImage)
                .containerBackground(for: .widget) { CountdownBackground(countdown: countdown, image: entry.image) }
        case .systemLarge, .systemExtraLarge:
            LargeCountdownView(countdown: countdown, upNext: entry.upNext, now: entry.date, hasImage: hasImage)
                .containerBackground(for: .widget) { CountdownBackground(countdown: countdown, image: entry.image) }
        case .accessoryCircular:
            CircularCountdownView(countdown: countdown, now: entry.date)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            RectangularCountdownView(countdown: countdown, now: entry.date)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            InlineCountdownView(countdown: countdown, now: entry.date)
                .containerBackground(for: .widget) { Color.clear }
        default:
            SmallCountdownView(countdown: countdown, now: entry.date, hasImage: hasImage)
                .containerBackground(for: .widget) { CountdownBackground(countdown: countdown, image: entry.image) }
        }
    }
}

struct CountdownWidget: Widget {
    static let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectCountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Keep an eye on the day you're looking forward to.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

#Preview("Small", as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: Countdown.samples[0], upNext: [], image: nil)
    CountdownEntry(date: .now, countdown: Countdown.samples[2], upNext: [], image: nil)
}

#Preview("Medium", as: .systemMedium) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: Countdown.samples[1], upNext: [], image: nil)
}

#Preview("Large", as: .systemLarge) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: Countdown.samples[0], upNext: Array(Countdown.samples.dropFirst()), image: nil)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: Countdown.samples[0], upNext: [], image: nil)
}

#Preview("Circular", as: .accessoryCircular) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, countdown: Countdown.samples[1], upNext: [], image: nil)
}
