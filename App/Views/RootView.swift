import SwiftUI

struct RootView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var editing: EditorRequest?
    @State private var pendingRepeat: Countdown?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            CountdownListView(
                onCreate: { editing = EditorRequest(countdown: Countdown(), isNew: true) },
                onEdit: { editing = EditorRequest(countdown: $0, isNew: false) },
                onShowSettings: { router.isShowingSettings = true }
            )
            .navigationDestination(for: UUID.self) { id in
                CountdownDetailView(id: id) { countdown in
                    editing = EditorRequest(countdown: countdown, isNew: false)
                }
            }
        }
        .sheet(item: $editing) { request in
            CountdownEditorView(countdown: request.countdown, isNew: request.isNew)
        }
        .sheet(isPresented: $router.isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $router.isShowingPremium) {
            PremiumView()
        }
        .sheet(isPresented: Binding(get: { shouldShowWelcome }, set: { if !$0 { hasSeenWelcome = true } })) {
            WelcomeView { hasSeenWelcome = true }
                .interactiveDismissDisabled()
        }
        .repeatChoice(for: $pendingRepeat) { countdown in
            editing = EditorRequest(countdown: countdown, isNew: true)
        }
        .onChange(of: router.isCreatingCountdown) { _, _ in
            handlePendingCreation()
        }
        .onAppear {
            if let url = ScreenshotMode.initialURL {
                router.open(url)
            }
            if let id = ScreenshotMode.editingID, let countdown = store.countdown(with: id) {
                editing = EditorRequest(countdown: countdown, isNew: false)
            }
            handlePendingCreation()
        }
    }

    private var shouldShowWelcome: Bool {
        switch ScreenshotMode.current {
        case .welcome: true
        case .samples, .empty, .homescreen, .lockscreen: false
        case nil: !hasSeenWelcome
        }
    }

    private func handlePendingCreation() {
        guard router.isCreatingCountdown else { return }
        router.isCreatingCountdown = false
        router.isShowingSettings = false
        let countdown = router.draft ?? Countdown()
        router.draft = nil
        if countdown.repeatRule.frequency == nil {
            editing = EditorRequest(countdown: countdown, isNew: true)
        } else {
            editing = nil
            pendingRepeat = countdown
        }
    }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let countdown: Countdown
    let isNew: Bool
}
