import SwiftUI
import UIKit

struct WidgetMetrics {
    let small: CGSize
    let medium: CGSize
    let large: CGSize
    let circular: CGSize
    let rectangular: CGSize
    let cornerRadius: CGFloat
    let contentMargin: CGFloat = 16

    @MainActor
    static var current: WidgetMetrics {
        let bounds = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size
            ?? CGSize(width: 393, height: 852)
        return metrics(width: min(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
    }

    static func metrics(width: CGFloat, height: CGFloat) -> WidgetMetrics {
        switch (width, height) {
        case (375, 667):
            return WidgetMetrics(side: 148, mediumWidth: 321, largeHeight: 324, accessory: 68, rectangularWidth: 153)
        case (375, 812):
            return WidgetMetrics(side: 155, mediumWidth: 329, largeHeight: 345, accessory: 70, rectangularWidth: 155)
        case (390, _), (393, _):
            return WidgetMetrics(side: 158, mediumWidth: 338, largeHeight: 354, accessory: 72, rectangularWidth: 158)
        case (414, 736):
            return WidgetMetrics(side: 159, mediumWidth: 348, largeHeight: 357, accessory: 72, rectangularWidth: 159)
        case (414, 896):
            return WidgetMetrics(side: 169, mediumWidth: 360, largeHeight: 379, accessory: 76, rectangularWidth: 169)
        case (428, _), (430, _):
            return WidgetMetrics(side: 170, mediumWidth: 364, largeHeight: 382, accessory: 76, rectangularWidth: 170)
        default:
            let delta = width - 390
            return WidgetMetrics(
                side: (158 + delta * 0.3).rounded(),
                mediumWidth: (338 + delta * 0.65).rounded(),
                largeHeight: (354 + delta * 0.7).rounded(),
                accessory: (72 + delta * 0.1).rounded(),
                rectangularWidth: (158 + delta * 0.3).rounded()
            )
        }
    }

    private init(side: CGFloat, mediumWidth: CGFloat, largeHeight: CGFloat, accessory: CGFloat, rectangularWidth: CGFloat) {
        small = CGSize(width: side, height: side)
        medium = CGSize(width: mediumWidth, height: side)
        large = CGSize(width: mediumWidth, height: largeHeight)
        circular = CGSize(width: accessory, height: accessory)
        rectangular = CGSize(width: rectangularWidth, height: accessory)
        cornerRadius = (side * 0.139).rounded()
    }
}

enum PreviewFamily: String, CaseIterable, Identifiable {
    case small, medium, large, lockScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        case .lockScreen: String(localized: "picker.lockScreen")
        }
    }
}

struct HomeWidgetPreview<Content: View>: View {
    let countdown: Countdown
    let image: UIImage?
    let size: CGSize
    let metrics: WidgetMetrics
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(metrics.contentMargin)
            .frame(width: size.width, height: size.height)
            .background {
                CountdownBackground(countdown: countdown, image: image)
            }
            .clipShape(.rect(cornerRadius: metrics.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}

struct WidgetFamilyPreview: View {
    let countdown: Countdown
    let image: UIImage?
    @Binding var family: PreviewFamily
    var now: Date = .now

    var body: some View {
        let metrics = WidgetMetrics.current
        VStack(spacing: 16) {
            Group {
                switch family {
                case .small:
                    HomeWidgetPreview(countdown: countdown, image: image, size: metrics.small, metrics: metrics) {
                        SmallCountdownView(countdown: countdown, now: now, hasImage: image != nil)
                    }
                case .medium:
                    HomeWidgetPreview(countdown: countdown, image: image, size: metrics.medium, metrics: metrics) {
                        MediumCountdownView(countdown: countdown, now: now, hasImage: image != nil)
                    }
                case .large:
                    HomeWidgetPreview(countdown: countdown, image: image, size: metrics.large, metrics: metrics) {
                        LargeCountdownView(countdown: countdown, now: now, hasImage: image != nil)
                    }
                case .lockScreen:
                    LockScreenPreview(countdown: countdown, now: now, metrics: metrics)
                }
            }
            .frame(maxWidth: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))

            Picker("Widget Size", selection: $family.animation(.snappy)) {
                ForEach(PreviewFamily.allCases) { family in
                    Text(family.title).tag(family)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct LockScreenPreview: View {
    let countdown: Countdown
    let now: Date
    var metrics: WidgetMetrics = .current

    var body: some View {
        VStack(spacing: 4) {
            InlineCountdownView(countdown: countdown, now: now)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.9))
            Text(clockText)
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 12) {
                CircularCountdownView(countdown: countdown, now: now)
                    .frame(width: metrics.circular.width, height: metrics.circular.height)
                RectangularCountdownView(countdown: countdown, now: now)
                    .frame(width: metrics.rectangular.width, height: metrics.rectangular.height)
            }
            .padding(.top, 6)
            .foregroundStyle(.white)
        }
        .tint(.white)
        .padding(.vertical, 22)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [countdown.tint.adjusting(brightness: -0.3), countdown.tint.adjusting(brightness: -0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private var clockText: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        var text = formatter.string(from: now)
        for symbol in [formatter.amSymbol, formatter.pmSymbol].compactMap({ $0 }) where !symbol.isEmpty {
            text = text.replacingOccurrences(of: symbol, with: "")
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
