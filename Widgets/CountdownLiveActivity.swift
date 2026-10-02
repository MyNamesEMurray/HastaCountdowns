import ActivityKit
import SwiftUI
import WidgetKit

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            CountdownActivityLockScreenView(countdown: context.state.countdown)
                .activityBackgroundTint(context.state.countdown.tint.adjusting(brightness: -0.45).opacity(0.85))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.countdown(context.state.countdown.id))
        } dynamicIsland: { context in
            let countdown = context.state.countdown
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivitySymbol(countdown: countdown, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityCountdownValue(countdown: countdown, size: 30, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(countdown.displayTitle)
                            .font(countdown.typeface.font(.headline))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(countdown.formattedDate())
                            .font(countdown.typeface.font(.caption, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityProgressBar(countdown: countdown)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: countdown.symbol)
                    .foregroundStyle(countdown.tint)
            } compactTrailing: {
                ActivityCompactValue(countdown: countdown)
                    .foregroundStyle(countdown.tint)
            } minimal: {
                Image(systemName: countdown.symbol)
                    .foregroundStyle(countdown.tint)
            }
            .widgetURL(DeepLink.countdown(countdown.id))
            .keylineTint(countdown.tint)
        }
    }
}

struct CountdownActivityLockScreenView: View {
    let countdown: Countdown

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActivitySymbol(countdown: countdown, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(countdown.displayTitle)
                        .font(countdown.typeface.font(.headline, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(countdown.formattedDate(style: .complete))
                        .font(countdown.typeface.font(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ActivityCountdownValue(countdown: countdown, size: 38, alignment: .trailing)
            }
            ActivityProgressBar(countdown: countdown)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

struct ActivitySymbol: View {
    let countdown: Countdown
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(countdown.tint.gradient)
            Image(systemName: countdown.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct ActivityCountdownValue: View {
    let countdown: Countdown
    let size: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        let now = Date.now
        let status = countdown.status(at: now)
        let target = countdown.nextOccurrence(after: now)
        VStack(alignment: alignment, spacing: -2) {
            if target > now && target.timeIntervalSince(now) < 86_400 {
                Text(timerInterval: now...target, countsDown: true)
                    .font(countdown.typeface.font(size: size * 0.8))
                    .monospacedDigit()
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                    .frame(maxWidth: 150, alignment: alignment == .trailing ? .trailing : .leading)
                Text("REMAINING")
                    .font(countdown.typeface.font(size: 10, weight: .semibold))
                    .opacity(0.75)
            } else if status.isToday {
                Text("Today")
                    .font(countdown.typeface.font(size: size * 0.8))
            } else {
                Text(status.number)
                    .font(countdown.typeface.font(size: size))
                    .monospacedDigit()
                Text(status.caption.uppercased())
                    .font(countdown.typeface.font(size: 10, weight: .semibold))
                    .opacity(0.75)
                    .lineLimit(1)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct ActivityCompactValue: View {
    let countdown: Countdown

    var body: some View {
        let now = Date.now
        let target = countdown.nextOccurrence(after: now)
        if target > now && target.timeIntervalSince(now) < 86_400 {
            Text(timerInterval: now...target, countsDown: true)
                .monospacedDigit()
                .frame(maxWidth: 64)
        } else {
            Text(countdown.status(at: now).compactPhrase)
                .monospacedDigit()
        }
    }
}

struct ActivityProgressBar: View {
    let countdown: Countdown

    var body: some View {
        let now = Date.now
        let target = countdown.nextOccurrence(after: now)
        let end = countdown.isAllDay ? Calendar.current.startOfDay(for: target) : target
        let start = min(
            countdown.previousOccurrence(before: target).map { countdown.isAllDay ? Calendar.current.startOfDay(for: $0) : $0 } ?? countdown.createdAt,
            now
        )
        if end > now {
            ProgressView(timerInterval: start...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(countdown.tint)
        }
    }
}
