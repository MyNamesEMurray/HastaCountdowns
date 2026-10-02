import SwiftUI
import UIKit

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for id: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) {
            return cached
        }
        guard let image = BackgroundImageStore.image(for: id, maxPixelSize: BackgroundImageStore.maxStoredPixelSize) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }
}

struct WidgetPreviewFrame<Content: View>: View {
    let countdown: Countdown
    var image: UIImage?
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                CountdownBackground(countdown: countdown, image: image)
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CountdownCard: View {
    @Environment(PurchaseManager.self) private var purchases
    let countdown: Countdown
    let now: Date

    var body: some View {
        let resolved = countdown.resolved(isPremium: purchases.isPremium)
        let image = resolved.backgroundImageID.flatMap { ImageCache.shared.image(for: $0) }
        WidgetPreviewFrame(countdown: resolved, image: image) {
            SmallCountdownView(countdown: resolved, now: now, hasImage: image != nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .contentShape(.rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(resolved.displayTitle), \(resolved.status(at: now).phrase)")
    }
}

struct LockScreenPreview: View {
    let countdown: Countdown
    let now: Date
    var height: CGFloat = 158

    var body: some View {
        VStack(spacing: 6) {
            Text(now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(now.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            HStack(spacing: 10) {
                CircularCountdownView(countdown: countdown, now: now)
                    .frame(width: 50, height: 50)
                RectangularCountdownView(countdown: countdown, now: now)
                    .frame(maxWidth: 150, minHeight: 50, maxHeight: 50)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            LinearGradient(
                colors: [countdown.tint.adjusting(brightness: -0.35), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}
