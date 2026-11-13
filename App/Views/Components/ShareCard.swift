import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct ShareCard: Transferable {
    let countdown: Countdown
    let now: Date

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await MainActor.run { try card.pngData() }
        }
    }

    @MainActor
    private func pngData() throws -> Data {
        let image = countdown.backgroundImageID.flatMap { ImageCache.shared.image(for: $0) }
        let renderer = ImageRenderer(content: ShareCardView(countdown: countdown, image: image, now: now))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

private struct ShareCardView: View {
    let countdown: Countdown
    let image: UIImage?
    let now: Date

    var body: some View {
        let palette = CountdownPalette(countdown: countdown, hasImage: image != nil, photoZones: image?.zones)
        VStack(spacing: 0) {
            LargeCountdownView(countdown: countdown, now: now, hasImage: image != nil)
            Text("Made with Hasta · hasta.day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .padding(28)
        .frame(width: 360, height: 450)
        .background { CountdownBackground(countdown: countdown, image: image) }
        .environment(\.photoZones, image?.zones)
        .environment(\.colorScheme, .light)
    }
}

struct CountdownShareLink: View {
    @Environment(PurchaseManager.self) private var purchases
    let countdown: Countdown
    var now: Date = .now

    var body: some View {
        let resolved = countdown.resolved(isPremium: purchases.isPremium)
        ShareLink(
            item: ShareCard(countdown: resolved, now: now),
            message: Text("\(resolved.shareText(at: now)) hasta.day"),
            preview: SharePreview(resolved.displayTitle, icon: Image(systemName: resolved.symbol))
        ) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}
