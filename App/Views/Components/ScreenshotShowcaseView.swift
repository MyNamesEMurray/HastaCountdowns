import SwiftUI

struct ScreenshotShowcaseView: View {
    enum Kind {
        case homeScreen
        case lockScreen
    }

    let kind: Kind
    var now: Date = .now

    var body: some View {
        switch kind {
        case .homeScreen:
            ShowcaseHomeScreen(countdowns: showcaseCountdowns, now: now)
        case .lockScreen:
            ShowcaseLockScreen(countdowns: showcaseCountdowns, now: now)
        }
    }

    private var showcaseCountdowns: [Countdown] {
        var samples = Countdown.samples
        samples[0].style = .night
        samples[3].typeface = .serif
        return samples
    }
}

private struct ShowcaseHomeScreen: View {
    let countdowns: [Countdown]
    let now: Date

    var body: some View {
        let metrics = WidgetMetrics.current
        let spacing = metrics.medium.width - metrics.small.width * 2
        VStack(spacing: spacing - 8) {
            HStack(spacing: spacing) {
                widget(countdowns[1], size: metrics.small, metrics: metrics) { countdown in
                    SmallCountdownView(countdown: countdown, now: now)
                }
                widget(countdowns[2], size: metrics.small, metrics: metrics) { countdown in
                    SmallCountdownView(countdown: countdown, now: now)
                }
            }
            widget(countdowns[0], size: metrics.medium, metrics: metrics) { countdown in
                MediumCountdownView(countdown: countdown, now: now)
            }
            widget(countdowns[3], size: metrics.large, metrics: metrics) { countdown in
                LargeCountdownView(
                    countdown: countdown,
                    upNext: [countdowns[4], countdowns[1], countdowns[2]],
                    now: now
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
        .background {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.6, 0.45], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.42), Color(red: 0.22, green: 0.20, blue: 0.55), Color(red: 0.42, green: 0.22, blue: 0.58),
                    Color(red: 0.05, green: 0.30, blue: 0.48), Color(red: 0.16, green: 0.24, blue: 0.52), Color(red: 0.55, green: 0.28, blue: 0.52),
                    Color(red: 0.03, green: 0.20, blue: 0.30), Color(red: 0.10, green: 0.14, blue: 0.32), Color(red: 0.30, green: 0.14, blue: 0.36),
                ]
            )
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func widget<Content: View>(
        _ countdown: Countdown,
        size: CGSize,
        metrics: WidgetMetrics,
        @ViewBuilder content: (Countdown) -> Content
    ) -> some View {
        VStack(spacing: 5) {
            HomeWidgetPreview(countdown: countdown, image: nil, size: size, metrics: metrics) {
                content(countdown)
            }
            Text("Hasta")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private struct ShowcaseLockScreen: View {
    let countdowns: [Countdown]
    let now: Date

    var body: some View {
        let metrics = WidgetMetrics.current
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(now, format: .dateTime.weekday(.abbreviated).day())
                InlineCountdownView(countdown: countdowns[0], now: now)
                    .labelStyle(.titleAndIcon)
            }
            .font(.system(size: 21, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 24)
            .foregroundStyle(.white.opacity(0.85))

            Text("9:41")
                .font(.system(size: 112, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, -6)

            HStack(spacing: 14) {
                RectangularCountdownView(countdown: countdowns[0], now: now)
                    .frame(width: metrics.rectangular.width, height: metrics.rectangular.height)
                CircularCountdownView(countdown: countdowns[1], now: now)
                    .frame(width: metrics.circular.width, height: metrics.circular.height)
                CircularCountdownView(countdown: countdowns[2], now: now)
                    .frame(width: metrics.circular.width, height: metrics.circular.height)
            }
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.top, 4)

            Spacer()

            HStack {
                quickAction("flashlight.off.fill")
                Spacer()
                quickAction("camera.fill")
            }
            .padding(.horizontal, 46)
            .padding(.bottom, 20)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.45], [0.45, 0.55], [1, 0.4],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.36), Color(red: 0.28, green: 0.14, blue: 0.46), Color(red: 0.20, green: 0.12, blue: 0.40),
                    Color(red: 0.62, green: 0.22, blue: 0.48), Color(red: 0.90, green: 0.38, blue: 0.40), Color(red: 0.56, green: 0.20, blue: 0.50),
                    Color(red: 0.98, green: 0.62, blue: 0.36), Color(red: 0.96, green: 0.48, blue: 0.32), Color(red: 0.86, green: 0.36, blue: 0.38),
                ]
            )
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func quickAction(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 50, height: 50)
            .background(.ultraThinMaterial, in: .circle)
    }
}
