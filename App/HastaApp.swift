import SwiftUI
import UserNotifications

@main
struct HastaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CountdownStore()
    @State private var purchases = PurchaseManager()
    @State private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(purchases)
                .environment(router)
                .onOpenURL { url in
                    router.open(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                store.refreshSideEffects()
            }
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var path: [UUID] = []
    var isCreatingCountdown = false
    var isShowingSettings = false
    var isShowingPremium = false

    func open(_ url: URL) {
        switch DeepLink.destination(for: url) {
        case .countdown(let id):
            isCreatingCountdown = false
            path = [id]
        case .newCountdown:
            path = []
            isCreatingCountdown = true
        case .settings:
            isShowingSettings = true
        case .premium:
            isShowingPremium = true
        case nil:
            break
        }
    }
}

enum ScreenshotMode: String {
    case samples
    case empty
    case welcome

    static var current: ScreenshotMode? {
        UserDefaults.standard.string(forKey: "HastaScreenshotMode").flatMap(ScreenshotMode.init(rawValue:))
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let string = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: string) else { return }
        await MainActor.run {
            AppRouter.shared.open(url)
        }
    }
}
