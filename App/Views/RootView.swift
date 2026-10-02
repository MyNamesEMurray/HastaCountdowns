import SwiftUI

struct RootView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var editing: EditorRequest?
    @State private var isShowingSettings = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            CountdownListView(
                onCreate: { editing = EditorRequest(countdown: Countdown(), isNew: true) },
                onEdit: { editing = EditorRequest(countdown: $0, isNew: false) },
                onShowSettings: { isShowingSettings = true }
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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: Binding(get: { !hasSeenWelcome }, set: { if !$0 { hasSeenWelcome = true } })) {
            WelcomeView { hasSeenWelcome = true }
                .interactiveDismissDisabled()
        }
        .onChange(of: router.isCreatingCountdown) { _, _ in
            handlePendingCreation()
        }
        .onAppear(perform: handlePendingCreation)
    }

    private func handlePendingCreation() {
        guard router.isCreatingCountdown else { return }
        router.isCreatingCountdown = false
        isShowingSettings = false
        editing = EditorRequest(countdown: Countdown(), isNew: true)
    }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let countdown: Countdown
    let isNew: Bool
}
