import XCTest

final class ScreenshotTests: XCTestCase {
    private struct Shot {
        let name: String
        let mode: String
        var screen: String?
        var edit: String?
        var premium = false
    }

    private let shots = [
        Shot(name: "01-welcome", mode: "welcome"),
        Shot(name: "02-empty", mode: "empty"),
        Shot(name: "03-home", mode: "samples", premium: true),
        Shot(name: "04-detail", mode: "samples", screen: "countdown/00000000-0000-0000-0000-000000000001", premium: true),
        Shot(name: "05-editor", mode: "samples", edit: "00000000-0000-0000-0000-000000000003", premium: true),
        Shot(name: "06-settings", mode: "samples", screen: "settings", premium: true),
        Shot(name: "07-premium", mode: "samples", screen: "premium"),
        Shot(name: "08-homescreen", mode: "homescreen", premium: true),
        Shot(name: "09-lockscreen", mode: "lockscreen", premium: true),
    ]

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureScreens() {
        for appearance in ["light", "dark"] {
            for shot in shots {
                capture(shot, appearance: appearance)
            }
        }
    }

    @MainActor
    private func capture(_ shot: Shot, appearance: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-HastaScreenshotMode", shot.mode, "-HastaScreenshotAppearance", appearance]
        if let screen = shot.screen {
            app.launchArguments += ["-HastaScreenshotScreen", screen]
        }
        if let edit = shot.edit {
            app.launchArguments += ["-HastaScreenshotEdit", edit]
        }
        if shot.premium {
            app.launchArguments += ["-HastaScreenshotPremium", "YES"]
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        sleep(2)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(appearance)-\(shot.name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
}
