import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(CountdownStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var isShowingPaywall = false
    @State private var reminderTime: Date = Calendar.current.date(from: ReminderPreferences.time) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if purchases.isPremium {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hasta Premium")
                                    .font(.headline)
                                Text("Unlocked. Thank you!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            isShowingPaywall = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        in: .rect(cornerRadius: 12, style: .continuous)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hasta Premium")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Photos, typefaces, styles and more. One-time purchase.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Appearance") {
                    NavigationLink {
                        AppIconPickerView(onLocked: { isShowingPaywall = true })
                    } label: {
                        Label("App Icon", systemImage: "app.badge")
                    }
                }

                Section {
                    DatePicker(selection: $reminderTime, displayedComponents: .hourAndMinute) {
                        Label("All-Day Reminder Time", systemImage: "bell")
                    }
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Notification Settings", systemImage: "gear")
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Reminders for all-day countdowns are delivered at this time.")
                }

                Section("Widgets") {
                    NavigationLink {
                        WidgetGuideContent()
                            .navigationTitle("Add Widgets")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("How to Add Widgets", systemImage: "square.grid.2x2")
                    }
                }

                Section {
                    Button {
                        Task { await purchases.restore() }
                    } label: {
                        Label("Restore Purchase", systemImage: "arrow.clockwise")
                    }
                    .disabled(purchases.isPurchasing)
                    Button {
                        requestReview()
                    } label: {
                        Label("Rate Hasta", systemImage: "star")
                    }
                    Link(destination: URL(string: "https://hasta.day/support/")!) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "https://hasta.day/privacy/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Support")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.versionString)
                } footer: {
                    Text("Your countdowns are stored only on this device. Hasta has no accounts, no ads, and no tracking.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: reminderTime) { _, newValue in
                ReminderPreferences.time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                store.refreshSideEffects()
            }
            .sheet(isPresented: $isShowingPaywall) {
                PremiumView()
            }
            .alert("Hasta Premium", isPresented: Binding(get: { purchases.errorMessage != nil && !isShowingPaywall }, set: { if !$0 { purchases.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchases.errorMessage ?? "")
            }
        }
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
