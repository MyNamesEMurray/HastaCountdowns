import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(CountdownStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var isShowingPaywall = false
    @State private var isConfirmingSyncOff = false
    @State private var syncError: String?
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
                        .tint(.primary)
                    }
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { isSyncEnabled },
                        set: { enabled in
                            if enabled {
                                store.sync?.setEnabled(true)
                            } else {
                                isConfirmingSyncOff = true
                            }
                        }
                    )) {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                    if isSyncEnabled {
                        LabeledContent("Status") {
                            Text(syncStatusText)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Keeps your countdowns, reminders, and photos on all your devices through your private iCloud account, and brings them back on a new iPhone. Hasta can't see your data. Turning sync off keeps your iCloud copy unless you choose to delete it.")
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
                    Text("Your countdowns are stored on your devices and, with iCloud Sync on, in your private iCloud account. Hasta has no accounts, no ads, and no tracking.")
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
            .confirmationDialog("Turn Off iCloud Sync?", isPresented: $isConfirmingSyncOff, titleVisibility: .visible) {
                Button("Turn Off") {
                    store.sync?.setEnabled(false)
                }
                Button("Turn Off and Delete from iCloud", role: .destructive) {
                    Task {
                        do {
                            try await store.sync?.deleteCloudData()
                        } catch {
                            syncError = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your countdowns stay on this iPhone either way. Deleting removes Hasta's data from iCloud; your other devices keep what they have but stop syncing.")
            }
            .alert("Couldn't Delete from iCloud", isPresented: Binding(get: { syncError != nil }, set: { if !$0 { syncError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncError ?? "")
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

extension SettingsView {
    private var isSyncEnabled: Bool {
        store.sync?.isEnabled ?? false
    }

    private var syncStatusText: String {
        switch store.sync?.status ?? .off {
        case .off: return "Off"
        case .checking: return "Checking iCloud…"
        case .unavailable(let message): return message
        case .syncing: return "Syncing…"
        case .upToDate(let date): return "Up to date · \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message): return "Couldn't sync. \(message)"
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
