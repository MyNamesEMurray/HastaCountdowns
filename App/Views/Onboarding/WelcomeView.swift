import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.system(size: 34, weight: .bold))
                        Text("Hasta")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    .padding(.top, 56)

                    VStack(alignment: .leading, spacing: 28) {
                        FeatureRow(
                            symbol: "hourglass",
                            color: .orange,
                            title: "Count Down to Anything",
                            detail: "Trips, birthdays, concerts, the last day of school. Add as many as you like."
                        )
                        FeatureRow(
                            symbol: "rectangle.grid.2x2.fill",
                            color: .pink,
                            title: "Widgets Everywhere",
                            detail: "Put countdowns on your Home Screen, Lock Screen and in StandBy."
                        )
                        FeatureRow(
                            symbol: "bell.badge.fill",
                            color: .red,
                            title: "Gentle Reminders",
                            detail: "Get a heads-up a week, a few days, or a day before the big day."
                        )
                        FeatureRow(
                            symbol: "lock.shield.fill",
                            color: .blue,
                            title: "Private by Design",
                            detail: "Your countdowns stay on your device. No accounts, no ads, no tracking."
                        )
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, 32)
            }

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .padding(.top, 12)
        }
    }
}

#Preview {
    WelcomeView {}
}
