import SwiftUI

struct CountdownDetailView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let onEdit: (Countdown) -> Void
    @State private var isConfirmingDelete = false
    @State private var isShowingWidgetGuide = false

    var body: some View {
        if let original = store.countdown(with: id) {
            content(original: original)
        } else {
            ContentUnavailableView("Countdown Deleted", systemImage: "trash")
        }
    }

    private func content(original: Countdown) -> some View {
        let countdown = original.resolved(isPremium: purchases.isPremium)
        let image = countdown.backgroundImageID.flatMap { ImageCache.shared.image(for: $0) }
        return ScrollView {
            VStack(spacing: 20) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 20) {
                        DetailHero(countdown: countdown, image: image, upNext: upNext(excluding: countdown), now: context.date)
                        TimeBreakdownView(countdown: countdown, now: context.date)
                    }
                }
                DetailInfoView(countdown: countdown)
                widgetSection(countdown: countdown, image: image)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(countdown.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { onEdit(original) }
            }
            ToolbarItem(placement: .secondaryAction) {
                ShareLink(item: countdown.shareText()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .confirmationDialog("Delete \(countdown.displayTitle)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Countdown", role: .destructive) {
                store.delete(original)
                dismiss()
            }
        } message: {
            Text("It will also be removed from any widgets.")
        }
        .sheet(isPresented: $isShowingWidgetGuide) {
            WidgetGuideView()
        }
    }

    private func upNext(excluding countdown: Countdown) -> [Countdown] {
        store.upcoming()
            .filter { $0.id != countdown.id }
            .map { $0.resolved(isPremium: purchases.isPremium) }
    }

    private func widgetSection(countdown: Countdown, image: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Widgets")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("How to Add") { isShowingWidgetGuide = true }
                    .font(.subheadline.weight(.semibold))
            }
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    let metrics = WidgetMetrics.current
                    HomeWidgetPreview(countdown: countdown, image: image, size: metrics.small, metrics: metrics) {
                        SmallCountdownView(countdown: countdown, now: .now, hasImage: image != nil)
                    }

                    HomeWidgetPreview(countdown: countdown, image: image, size: metrics.medium, metrics: metrics) {
                        MediumCountdownView(countdown: countdown, now: .now, hasImage: image != nil)
                    }

                    LockScreenPreview(countdown: countdown, now: .now, metrics: metrics)
                        .frame(width: metrics.medium.width)
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

private struct DetailHero: View {
    let countdown: Countdown
    let image: UIImage?
    let upNext: [Countdown]
    let now: Date

    var body: some View {
        let metrics = WidgetMetrics.current
        GeometryReader { proxy in
            HomeWidgetPreview(countdown: countdown, image: image, size: metrics.large, metrics: metrics) {
                LargeCountdownView(countdown: countdown, upNext: upNext, now: now, hasImage: image != nil)
            }
            .scaleEffect(proxy.size.width / metrics.large.width, anchor: .topLeading)
        }
        .aspectRatio(metrics.large.width / metrics.large.height, contentMode: .fit)
    }
}

private struct TimeBreakdownView: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let target = countdown.nextOccurrence(after: now)
        let end = countdown.isAllDay ? Calendar.current.startOfDay(for: target) : target
        let isPast = end < now
        let parts = Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: isPast ? end : now,
            to: isPast ? now : end
        )
        VStack(alignment: .leading, spacing: 10) {
            Text(isPast ? "Time Since" : "Time Remaining")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(spacing: 0) {
                unit(parts.day ?? 0, "days")
                Divider().frame(height: 36)
                unit(parts.hour ?? 0, "hours")
                Divider().frame(height: 36)
                unit(parts.minute ?? 0, "min")
                Divider().frame(height: 36)
                unit(parts.second ?? 0, "sec")
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func unit(_ value: Int, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(ScreenshotMode.current == nil ? .snappy : nil, value: value)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailInfoView: View {
    let countdown: Countdown

    var body: some View {
        VStack(spacing: 0) {
            row("Date", systemImage: "calendar", value: countdown.formattedDate(style: .long))
            Divider().padding(.leading, 44)
            row("Repeats", systemImage: "repeat", value: countdown.repeatRule.title)
            Divider().padding(.leading, 44)
            row("Reminders", systemImage: "bell", value: reminderSummary)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var reminderSummary: String {
        let rules = countdown.reminders.sortedByLeadTime
        guard let first = rules.first else { return String(localized: "None") }
        if rules.count > 1 { return String(localized: "reminders.count \(rules.count)") }
        return first.title(isAllDay: countdown.isAllDay, defaultTime: ReminderPreferences.time)
    }

    private func row(_ title: String, systemImage: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(countdown.tint)
                .frame(width: 20)
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
