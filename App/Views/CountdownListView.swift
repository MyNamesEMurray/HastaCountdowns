import SwiftUI

struct CountdownListView: View {
    @Environment(CountdownStore.self) private var store
    let onCreate: () -> Void
    let onEdit: (Countdown) -> Void
    let onShowSettings: () -> Void
    @State private var pendingDelete: Countdown?

    private let columns = [GridItem(.adaptive(minimum: 156, maximum: 260), spacing: 14)]

    var body: some View {
        Group {
            if store.countdowns.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Hasta")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape", action: onShowSettings)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Countdown", systemImage: "plus", action: onCreate)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.displayTitle ?? String(localized: "Countdown"))?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Countdown", role: .destructive) {
                if let pendingDelete {
                    withAnimation { store.delete(pendingDelete) }
                }
                pendingDelete = nil
            }
        } message: {
            Text("It will also be removed from any widgets.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Countdowns", systemImage: "hourglass")
        } description: {
            Text("Count down to a trip, a birthday, or anything you're looking forward to.")
        } actions: {
            Button("Add Countdown", action: onCreate)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
    }

    private var list: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let upcoming = store.upcoming(at: now)
            let past = store.past(at: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !upcoming.isEmpty {
                        grid(upcoming, now: now)
                    }
                    if !past.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Past")
                                .font(.title3.weight(.bold))
                            grid(past, now: now)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func grid(_ countdowns: [Countdown], now: Date) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(countdowns) { countdown in
                NavigationLink(value: countdown.id) {
                    CountdownCard(countdown: countdown, now: now)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { onEdit(countdown) }
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        withAnimation { store.duplicate(countdown) }
                    }
                    ShareLink(item: countdown.shareText(at: now)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingDelete = countdown
                    }
                }
            }
        }
    }
}

extension Countdown {
    func shareText(at now: Date = .now) -> String {
        let status = self.status(at: now)
        let phrase = status.phrase.prefix(1).lowercased() + status.phrase.dropFirst()
        switch status.phase {
        case .today: return String(localized: "share.today \(displayTitle)")
        case .upcoming: return String(localized: "share.upcoming \(displayTitle) \(String(phrase))")
        case .past: return String(localized: "share.past \(displayTitle) \(String(phrase))")
        }
    }
}
