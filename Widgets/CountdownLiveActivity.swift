import ActivityKit
import SwiftUI
import WidgetKit

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            let state = context.state
            let tint = Color(hex: state.tintHex) ?? .blue
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: state.symbol)
                    Text(state.title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(timerInterval: state.remainingRange, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                ProgressView(timerInterval: state.elapsedRange, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(.white)
            }
            .foregroundStyle(.white)
            .padding(16)
            .activityBackgroundTint(tint.adjusting(brightness: -0.15))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(DeepLink.countdown(context.attributes.countdownID))
        } dynamicIsland: { context in
            let state = context.state
            let tint = Color(hex: state.tintHex) ?? .blue
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.symbol)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: state.remainingRange, countsDown: true)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: state.elapsedRange, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(tint)
                }
            } compactLeading: {
                Image(systemName: state.symbol).foregroundStyle(tint)
            } compactTrailing: {
                Text(timerInterval: state.remainingRange, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: state.symbol).foregroundStyle(tint)
            }
            .widgetURL(DeepLink.countdown(context.attributes.countdownID))
            .keylineTint(tint)
        }
    }
}
