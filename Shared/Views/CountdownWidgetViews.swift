import SwiftUI
import WidgetKit

struct CountdownPalette {
    let primary: Color
    let secondary: Color
    let number: Color
    let accent: Color
    let track: Color

    init(countdown: Countdown, hasImage: Bool, renderingMode: WidgetRenderingMode = .fullColor) {
        if renderingMode != .fullColor {
            primary = .primary
            secondary = .secondary
            number = .primary
            accent = .primary
            track = .primary.opacity(0.25)
        } else if hasImage || countdown.style.usesLightForeground {
            primary = .white
            secondary = .white.opacity(0.78)
            number = .white
            accent = .white
            track = .white.opacity(0.3)
        } else {
            primary = .primary
            secondary = .secondary
            number = countdown.tint
            accent = countdown.tint
            track = countdown.tint.opacity(0.2)
        }
    }
}

struct CountdownBackground: View {
    let countdown: Countdown
    var image: UIImage?

    var body: some View {
        if let image {
            ZStack {
                Color.black
                FramedPhoto(image: image, framing: countdown.backgroundFraming ?? .centered)
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.2), .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            switch countdown.style {
            case .classic:
                Rectangle().fill(countdown.tint.gradient)
            case .minimal:
                Color(uiColor: .secondarySystemGroupedBackground)
            case .vivid:
                VividBackground(tint: countdown.tint)
            case .night:
                ZStack {
                    Color.black
                    RadialGradient(
                        colors: [countdown.tint.opacity(0.65), countdown.tint.opacity(0.15), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 260
                    )
                }
            }
        }
    }
}

struct FramedPhoto: View {
    let image: UIImage
    let framing: BackgroundFraming

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size
            let imageSize = image.size
            let rect = framing.visibleRect(imageSize: imageSize, containerSize: container)
            let scale = rect.width > 0 ? container.width / (rect.width * imageSize.width) : 1
            let displayed = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .frame(width: displayed.width, height: displayed.height)
                .offset(x: -rect.minX * displayed.width, y: -rect.minY * displayed.height)
        }
        .clipped()
    }
}

private struct VividBackground: View {
    let tint: Color

    var body: some View {
        let warm = tint.shiftingHue(by: -0.08)
        let cool = tint.shiftingHue(by: 0.1)
        let deep = tint.adjusting(brightness: -0.25)
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                warm, tint, cool,
                tint, cool, deep,
                deep, tint, warm,
            ]
        )
    }
}

struct CountdownNumberView: View {
    let countdown: Countdown
    let status: CountdownStatus
    let now: Date
    let size: CGFloat
    let palette: CountdownPalette
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: -2) {
            Group {
                if countdown.isLiveToday(at: now) {
                    Text(timerInterval: now...status.target, countsDown: true)
                        .font(countdown.typeface.font(size: size * 0.6))
                        .monospacedDigit()
                        .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                } else if status.isToday {
                    Text("Today")
                        .font(countdown.typeface.font(size: size * 0.7))
                } else {
                    Text(status.number)
                        .font(countdown.typeface.font(size: size))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(palette.number)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()

            if !status.isToday {
                Text(status.caption.uppercased())
                    .font(countdown.typeface.font(size: max(10, size * 0.2), weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if !countdown.isAllDay {
                Text(status.target.formatted(date: .omitted, time: .shortened).uppercased())
                    .font(countdown.typeface.font(size: max(10, size * 0.2), weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct ProgressCapsule: View {
    let value: Double
    let color: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.height, proxy.size.width * value))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
    }
}

struct SmallCountdownView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let countdown: Countdown
    let now: Date
    var hasImage = false

    var body: some View {
        let status = countdown.status(at: now)
        let palette = CountdownPalette(countdown: countdown, hasImage: hasImage, renderingMode: renderingMode)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: countdown.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .widgetAccentable()
                Spacer(minLength: 0)
                if countdown.repeatRule != .never {
                    Image(systemName: "repeat")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.secondary)
                }
            }
            Spacer(minLength: 0)
            CountdownNumberView(countdown: countdown, status: status, now: now, size: 50, palette: palette)
            Text(countdown.displayTitle)
                .font(countdown.typeface.font(.subheadline))
                .foregroundStyle(palette.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .allowsTightening(true)
                .layoutPriority(1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumCountdownView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let countdown: Countdown
    let now: Date
    var hasImage = false

    var body: some View {
        let status = countdown.status(at: now)
        let palette = CountdownPalette(countdown: countdown, hasImage: hasImage, renderingMode: renderingMode)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: countdown.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .widgetAccentable()
                    Spacer(minLength: 0)
                    Text(countdown.displayTitle)
                        .font(countdown.typeface.font(.headline, weight: .bold))
                        .foregroundStyle(palette.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.45)
                        .allowsTightening(true)
                        .layoutPriority(1)
                    Text(countdown.formattedDate(at: now))
                        .font(countdown.typeface.font(.caption, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                CountdownNumberView(countdown: countdown, status: status, now: now, size: 62, palette: palette, alignment: .trailing)
            }
            if !status.isPast {
                ProgressCapsule(value: countdown.progress(at: now), color: palette.number, track: palette.track)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LargeCountdownView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let countdown: Countdown
    let upNext: [Countdown]
    let now: Date
    var hasImage = false

    var body: some View {
        let status = countdown.status(at: now)
        let palette = CountdownPalette(countdown: countdown, hasImage: hasImage, renderingMode: renderingMode)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: countdown.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .widgetAccentable()
                Spacer(minLength: 0)
                if countdown.repeatRule != .never {
                    Label(countdown.repeatRule.title, systemImage: "repeat")
                        .font(countdown.typeface.font(.caption, weight: .semibold))
                        .foregroundStyle(palette.secondary)
                }
            }
            Spacer(minLength: 0)
            CountdownNumberView(countdown: countdown, status: status, now: now, size: 92, palette: palette)
            Text(countdown.displayTitle)
                .font(countdown.typeface.font(.title2, weight: .bold))
                .foregroundStyle(palette.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.45)
                .allowsTightening(true)
                .layoutPriority(1)
                .padding(.top, 4)
            Text(countdown.formattedDate(at: now, style: .complete))
                .font(countdown.typeface.font(.subheadline, weight: .medium))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
            if !status.isPast {
                ProgressCapsule(value: countdown.progress(at: now), color: palette.number, track: palette.track)
                    .padding(.top, 12)
            }
            if !upNext.isEmpty {
                VStack(spacing: 7) {
                    ForEach(upNext.prefix(3)) { other in
                        let otherStatus = other.status(at: now)
                        HStack(spacing: 8) {
                            Image(systemName: other.symbol)
                                .font(.footnote.weight(.semibold))
                                .frame(width: 18)
                                .widgetAccentable()
                            Text(other.displayTitle)
                                .font(countdown.typeface.font(.subheadline, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .allowsTightening(true)
                            Spacer(minLength: 4)
                            Text(otherStatus.isToday ? "Today" : "\(otherStatus.number) \(otherStatus.unitLabel)")
                                .font(countdown.typeface.font(.subheadline, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(palette.primary)
                    }
                }
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CircularCountdownView: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let status = countdown.status(at: now)
        Gauge(value: status.isPast ? 1 : countdown.progress(at: now)) {
            Image(systemName: countdown.symbol)
        } currentValueLabel: {
            if status.isToday {
                Image(systemName: countdown.symbol)
                    .font(.system(size: 20, weight: .semibold))
            } else {
                VStack(spacing: -3) {
                    Text(status.number)
                        .font(countdown.typeface.font(size: 20, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(status.unitLabel.uppercased())
                        .font(countdown.typeface.font(size: 8, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 2)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct RectangularCountdownView: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let status = countdown.status(at: now)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: countdown.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .imageScale(.small)
                    .frame(width: 14, height: 14)
                Text(countdown.displayTitle)
                    .font(countdown.typeface.font(.subheadline, weight: .semibold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
            .widgetAccentable()

            Group {
                if countdown.isLiveToday(at: now) {
                    Text(timerInterval: now...status.target, countsDown: true)
                        .font(countdown.typeface.font(size: 22))
                        .monospacedDigit()
                } else if status.isToday {
                    Text("Today")
                        .font(countdown.typeface.font(size: 22))
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(status.number)
                            .font(countdown.typeface.font(size: 24))
                            .monospacedDigit()
                        Text(status.isPast ? "\(status.unitLabel) ago" : status.unitLabel)
                            .font(countdown.typeface.font(.subheadline))
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(status.remainder.map { "+\($0) · \(countdown.formattedDate(at: now))" } ?? countdown.formattedDate(at: now))
                .font(countdown.typeface.font(.caption, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineCountdownView: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let status = countdown.status(at: now)
        ViewThatFits {
            Label("\(countdown.displayTitle) \(status.phrase)", systemImage: countdown.symbol)
            Label(status.phrase, systemImage: countdown.symbol)
            Label(status.compactPhrase, systemImage: countdown.symbol)
        }
    }
}

struct UpNextRow: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        let status = countdown.status(at: now)
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(countdown.tint.gradient)
                Image(systemName: countdown.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text(countdown.displayTitle)
                    .font(countdown.typeface.font(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Text(countdown.formattedDate(at: now))
                    .font(countdown.typeface.font(.caption, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if status.isToday {
                Text("Today")
                    .font(countdown.typeface.font(size: 17))
                    .foregroundStyle(countdown.tint)
                    .widgetAccentable()
            } else {
                VStack(alignment: .trailing, spacing: -2) {
                    Text(status.number)
                        .font(countdown.typeface.font(size: 22))
                        .monospacedDigit()
                        .foregroundStyle(countdown.tint)
                        .widgetAccentable()
                    Text(status.unitLabel.uppercased())
                        .font(countdown.typeface.font(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct UpNextView: View {
    let countdowns: [Countdown]
    let now: Date
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Up Next")
                .font(.headline)
                .foregroundStyle(.secondary)
            if countdowns.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing on the horizon. Open Hasta to add a countdown.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(countdowns.prefix(limit)) { countdown in
                    Link(destination: DeepLink.countdown(countdown.id)) {
                        UpNextRow(countdown: countdown, now: now)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct EmptyCountdownView: View {
    var compact = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: compact ? 22 : 30, weight: .semibold))
                .foregroundStyle(.tint)
                .widgetAccentable()
            if !compact {
                Text("Add a Countdown")
                    .font(.headline)
                Text("Tap to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    func shiftingHue(by amount: CGFloat) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        var shifted = (hue + amount).truncatingRemainder(dividingBy: 1)
        if shifted < 0 { shifted += 1 }
        return Color(hue: shifted, saturation: saturation, brightness: brightness, opacity: alpha)
    }

    func adjusting(brightness delta: CGFloat) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return self }
        return Color(hue: hue, saturation: saturation, brightness: min(1, max(0, brightness + delta)), opacity: alpha)
    }
}
