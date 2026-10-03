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
