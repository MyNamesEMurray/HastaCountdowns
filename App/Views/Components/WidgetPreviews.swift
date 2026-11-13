import SwiftUI
import UIKit

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for id: String, maxPixelSize: CGFloat = BackgroundImageStore.maxStoredPixelSize) -> UIImage? {
        let key = "\(id)@\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = BackgroundImageStore.image(for: id, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

struct WidgetPreviewFrame<Content: View>: View {
    let countdown: Countdown
    var image: UIImage?
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    @State private var size = CGSize(width: 1, height: 1)

    var body: some View {
        content
            .environment(\.photoZones, image?.zones(framing: countdown.backgroundFraming, containerSize: size))
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .background {
                CountdownBackground(countdown: countdown, image: image)
                    .allowsHitTesting(false)
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
