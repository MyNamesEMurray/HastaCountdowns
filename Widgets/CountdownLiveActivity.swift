import ActivityKit
import SwiftUI
import WidgetKit

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            let state = context.state
            let display = ActivityDisplay(id: context.attributes.countdownID)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: display.symbol)
                    Text(display.title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    RemainingLabel(state: state, isStale: context.isStale)
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                ProgressView(timerInterval: state.elapsedRange, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(.white)
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(display.tint.adjusting(brightness: -0.15))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(DeepLink.countdown(context.attributes.countdownID))
        } dynamicIsland: { context in
            let state = context.state
            let display = ActivityDisplay(id: context.attributes.countdownID)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: display.symbol)
                        .font(.title2)
                        .foregroundStyle(display.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RemainingLabel(state: state, isStale: context.isStale)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(display.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: state.elapsedRange, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(display.tint)
                }
            } compactLeading: {
                Image(systemName: display.symbol).foregroundStyle(display.tint)
            } compactTrailing: {
                RemainingLabel(state: state, isStale: context.isStale)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 58, alignment: .trailing)
            } minimal: {
                Image(systemName: display.symbol).foregroundStyle(display.tint)
            }
            .widgetURL(DeepLink.countdown(context.attributes.countdownID))
            .keylineTint(display.tint)
        }
    }
}

private struct ActivityDisplay {
    let title: String
    let symbol: String
    let tint: Color

    init(id: UUID) {
        let countdown = CountdownRepository.load().first { $0.id == id }
        title = countdown?.displayTitle ?? String(localized: "Countdown")
        symbol = countdown?.symbol ?? "hourglass"
        tint = countdown?.tint ?? .blue
    }
}

private struct RemainingLabel: View {
    let state: CountdownActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        Group {
            if isStale {
                Text("Now")
            } else {
                Text(timerInterval: state.remainingRange, countsDown: true)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}
