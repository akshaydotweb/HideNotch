import CoreGraphics
import Testing
@testable import HideNotchCore

@MainActor
struct OverlayControllerTests {
    @Test func preparesSystemAppearanceOnlyWhenEnabling() {
        let screens = FakeScreens()
        let factory = WindowFactory()
        var calls = 0
        let overlay = OverlayController(screens: screens, makeWindow: factory.make, onEnable: { calls += 1 })
        #expect(calls == 0)
        overlay.isEnabled = true
        #expect(calls == 1)
        overlay.refresh()
        overlay.isEnabled = true
        overlay.suspend()
        overlay.resume()
        #expect(calls == 1)
        overlay.isEnabled = false
        #expect(calls == 1)
        overlay.isEnabled = true
        #expect(calls == 2)
    }

    let screens = FakeScreens()
    let factory = WindowFactory()

    func makeController() -> OverlayController {
        OverlayController(screens: screens, makeWindow: factory.make)
    }

    @Test func newControllerIsDisabled() {
        screens.list = [Screens.notched]
        let controller = makeController()
        #expect(!controller.isEnabled)
        #expect(factory.made.isEmpty)
    }

    @Test func suspendedOverlayIgnoresRefreshAndRestoresWithoutAnimation() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        controller.suspend()
        #expect(!factory.made[0].isShown)
        #expect(controller.isEnabled)
        controller.refresh()
        controller.roundedCornersEnabled = false
        #expect(!factory.made[0].isShown)
        #expect(factory.made.count == 1)

        controller.resume()
        #expect(factory.made.count == 1)
        #expect(factory.made[0].isShown)
        #expect(!factory.made[0].animatedShow)
        #expect(!factory.made[0].roundedCornersEnabled)
    }

    @Test func disablingWhileSuspendedDoesNotRestoreOverlay() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        controller.suspend()
        controller.isEnabled = false
        controller.resume()
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func enablingShowsBarOnNotchedScreenOnly() {
        screens.list = [Screens.notched, Screens.external]
        let controller = makeController()
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
        #expect(factory.made[0].isShown)
        #expect(factory.made[0].frame == Screens.notched.frame)
        #expect(factory.made[0].menuBarHeight == 39)
    }

    @Test func includingScreensWithoutNotchShowsBarOnEveryScreen() {
        screens.list = [Screens.notched, Screens.external]
        let controller = makeController()
        controller.isEnabled = true
        controller.screensWithoutNotchEnabled = true
        #expect(controller.windows.count == 2)
        #expect(factory.made[1].frame == Screens.external.frame)
        #expect(factory.made[1].menuBarHeight == 25)
        controller.screensWithoutNotchEnabled = false
        #expect(controller.windows.count == 1)
        #expect(!factory.made[1].isShown)
    }

    @Test func refreshWhileDisabledCreatesNothing() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.refresh()
        #expect(factory.made.isEmpty)
    }

    @Test func refreshMovesExistingWindow() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        var resized = Screens.notched
        resized.frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        resized.visibleFrame = CGRect(x: 0, y: 0, width: 1512, height: 945)
        resized.safeAreaTop = 32
        screens.list = [resized]
        controller.refresh()
        #expect(factory.made.count == 1)
        #expect(factory.made[0].frame == resized.frame)
        #expect(factory.made[0].menuBarHeight == 37)
    }

    @Test func refreshRemovesWindowWhenScreenGone() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        screens.list = [Screens.external]
        controller.refresh()
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func disablingHidesAll() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        controller.isEnabled = false
        #expect(controller.windows.isEmpty)
        #expect(!factory.made[0].isShown)
    }

    @Test func animatedDisableRetainsWindowsAndWaitsForEveryScreen() {
        screens.list = [Screens.notched, Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        factory.made.forEach { $0.delaysHide = true }
        controller.isEnabled = false
        #expect(controller.windows.count == 2)
        #expect(factory.made.allSatisfy { $0.isShown })
        var completed = false
        controller.hideAll { completed = true }
        factory.made[0].completeHide()
        #expect(!completed)
        #expect(controller.windows.count == 1)
        factory.made[1].completeHide()
        #expect(completed)
        #expect(controller.windows.isEmpty)
    }

    @Test func repeatedRefreshIsIdempotent() {
        screens.list = [Screens.notched]
        let controller = makeController()
        controller.isEnabled = true
        for _ in 0..<5 { controller.refresh() }
        #expect(controller.windows.count == 1)
        #expect(factory.made.count == 1)
    }

    @Test func reEnableReusesSlots() {
        screens.list = [Screens.notched]
        let controller = makeController()
        for _ in 0..<3 {
            controller.isEnabled = true
            controller.isEnabled = false
        }
        controller.isEnabled = true
        #expect(controller.windows.count == 1)
        #expect(factory.made.filter(\.isShown).count == 1)
    }
}
