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
                        DetailHero(countdown: countdown, image: image, now: context.date)
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
                    WidgetPreviewFrame(countdown: countdown, image: image) {
                        SmallCountdownView(countdown: countdown, now: .now, hasImage: image != nil)
                    }
                    .frame(width: 158, height: 158)

                    WidgetPreviewFrame(countdown: countdown, image: image) {
                        MediumCountdownView(countdown: countdown, now: .now, hasImage: image != nil)
                    }
                    .frame(width: 338, height: 158)

                    LockScreenPreview(countdown: countdown, now: .now)
                        .frame(width: 240)
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
    let now: Date

    var body: some View {
        let status = countdown.status(at: now)
        let palette = CountdownPalette(countdown: countdown, hasImage: image != nil)
        WidgetPreviewFrame(countdown: countdown, image: image, cornerRadius: 32, padding: 24) {
            VStack(spacing: 6) {
                Image(systemName: countdown.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.bottom, 6)
                Text(countdown.displayTitle)
                    .font(countdown.typeface.font(.title, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .multilineTextAlignment(.center)
                Text(countdown.formattedDate(at: now, style: .complete))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 16)
                if status.isToday && !countdown.isLiveToday(at: now) {
                    Text("Today")
                        .font(countdown.typeface.font(size: 72))
                        .foregroundStyle(palette.number)
                } else if countdown.isLiveToday(at: now) {
                    Text(timerInterval: now...status.target, countsDown: true)
                        .font(countdown.typeface.font(size: 64))
                        .monospacedDigit()
                        .foregroundStyle(palette.number)
                        .multilineTextAlignment(.center)
                } else {
                    Text(status.number)
                        .font(countdown.typeface.font(size: 104))
                        .monospacedDigit()
                        .foregroundStyle(palette.number)
                        .contentTransition(.numericText(countsDown: !status.isPast))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(status.caption.uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 360)
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

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted())
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: value)
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
            if !countdown.status().isPast {
                Divider().padding(.leading, 44)
                row("Progress", systemImage: "chart.bar.fill", value: countdown.progress().formatted(.percent.precision(.fractionLength(0))))
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var reminderSummary: String {
        guard !countdown.reminders.isEmpty else { return "None" }
        return countdown.reminders.sorted().map { $0.title(isAllDay: countdown.isAllDay) }.joined(separator: ", ")
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
