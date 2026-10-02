import SwiftUI

struct PremiumView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        FeatureRow(
                            symbol: "photo.fill.on.rectangle.fill",
                            color: .blue,
                            title: "Photo Backgrounds",
                            detail: "Put your favorite photo behind any countdown widget."
                        )
                        FeatureRow(
                            symbol: "textformat",
                            color: .purple,
                            title: "Typefaces & Styles",
                            detail: "Serif, Mono and Condensed type, plus Vivid and Night widget styles."
                        )
                        FeatureRow(
                            symbol: "paintpalette.fill",
                            color: .orange,
                            title: "Custom Colors",
                            detail: "Pick any color, not just the ones in the palette."
                        )
                        FeatureRow(
                            symbol: "app.badge.fill",
                            color: .pink,
                            title: "App Icons",
                            detail: "Choose an alternate icon for your Home Screen."
                        )
                        FeatureRow(
                            symbol: "heart.fill",
                            color: .red,
                            title: "Support Indie Development",
                            detail: "Help keep Hasta free for everyone, with no ads and no subscriptions."
                        )
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                purchaseFooter
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .alert("Hasta Premium", isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: .pink.opacity(0.35), radius: 16, y: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Hasta Premium")
                .font(.largeTitle.weight(.bold))
            Text(purchases.isPremium ? "Thank you for supporting Hasta." : "Make every countdown your own.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var purchaseFooter: some View {
        VStack(spacing: 10) {
            if purchases.isPremium {
                Label("Premium Unlocked", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Button {
                    Task { await purchases.purchase() }
                } label: {
                    Group {
                        if purchases.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(purchases.displayPrice.map { "Unlock for \($0)" } ?? "Unlock Premium")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(purchases.isPurchasing)

                Text("One-time purchase. No subscription, ever.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Restore Purchase") {
                    Task { await purchases.restore() }
                }
                .font(.footnote.weight(.semibold))
                .disabled(purchases.isPurchasing)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
