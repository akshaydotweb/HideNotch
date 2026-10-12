import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct StatusItemControllerTests {
    let suite = "HideNotchTests.\(UUID().uuidString)"
    let screens = FakeScreens()
    let factory = WindowFactory()
    let login = FakeLoginItem()
    let confirm = ConfirmSpy()
    let backgroundAlert = ConfirmSpy()

    func makeSUT(overlayEnabled: Bool = true) -> (StatusItemController, Preferences, OverlayController) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let prefs = Preferences(defaults: defaults)
        prefs.overlayEnabled = overlayEnabled
        screens.list = [Screens.notched]
        let overlay = OverlayController(screens: screens, makeWindow: factory.make)
        overlay.isEnabled = prefs.overlayEnabled
        let sut = StatusItemController(
            preferences: prefs, overlay: overlay, loginItem: login, confirmHidingIcon: confirm.ask,
            informSystemBackground: { _ = backgroundAlert.ask() })
        return (sut, prefs, overlay)
    }

    @Test func menuHasToggleLoginAndQuit() {
        let (sut, _, _) = makeSUT()
        #expect(sut.menu.items.map(\.title) == [L10n.hideNotch, L10n.roundedScreenCorners, L10n.displaysWithoutNotch, L10n.launchAtLogin, L10n.showMenuBarIcon, "", L10n.quit])
        #expect(sut.menu.items[5].isSeparatorItem)
    }

    @Test(arguments: [true, false])
    func togglingCornersUpdatesPreferenceAndOverlayWithoutEnablingIt(overlayEnabled: Bool) {
        let (sut, prefs, overlay) = makeSUT(overlayEnabled: overlayEnabled)
        sut.toggleRoundedCorners()
        #expect(!prefs.roundedCornersEnabled)
        #expect(!overlay.roundedCornersEnabled)
        #expect(overlay.isEnabled == overlayEnabled)
        #expect(sut.cornersMenuItem.state == .off)
        if overlayEnabled {
            #expect(factory.made.count == 1)
            #expect(!factory.made[0].roundedCornersEnabled)
            #expect(factory.made[0].isShown)
        } else {
            #expect(factory.made.isEmpty)
        }
        sut.toggleRoundedCorners()
        #expect(prefs.roundedCornersEnabled)
        #expect(overlay.roundedCornersEnabled)
        #expect(sut.cornersMenuItem.state == .on)
        if overlayEnabled {
            #expect(factory.made.count == 1)
            #expect(factory.made[0].roundedCornersEnabled)
        }
    }

    @Test func togglingScreensWithoutNotchUpdatesPreferenceOverlayAndMenu() {
        let (sut, prefs, overlay) = makeSUT()
        screens.list = [Screens.notched, Screens.external]
        sut.toggleScreensWithoutNotch()
        #expect(prefs.screensWithoutNotchEnabled)
        #expect(overlay.windows.count == 2)
        #expect(sut.screensWithoutNotchMenuItem.state == .on)
    }

    @Test func hidingIconKeepsOverlayEnabledAndReopeningRestoresAccess() {
        let (sut, prefs, overlay) = makeSUT()
        sut.install()
        defer {
            if let item = sut.statusItem { NSStatusBar.system.removeStatusItem(item) }
        }
        #expect(sut.statusItem?.isVisible == true)
        sut.toggleMenuBarIcon()
        #expect(confirm.calls == 1)
        #expect(!prefs.showMenuBarIcon)
        #expect(sut.statusItem?.isVisible == false)
        #expect(sut.iconMenuItem.state == .off)
        #expect(overlay.isEnabled)

        sut.restoreMenuBarIcon()
        #expect(prefs.showMenuBarIcon)
        #expect(sut.statusItem?.isVisible == true)
        #expect(sut.iconMenuItem.state == .on)
    }

    @Test func installingHonorsHiddenIconPreference() {
        let (sut, prefs, _) = makeSUT()
        prefs.showMenuBarIcon = false
        sut.install()
        defer {
            if let item = sut.statusItem { NSStatusBar.system.removeStatusItem(item) }
        }
        #expect(sut.statusItem?.isVisible == false)
        #expect(sut.iconMenuItem.state == .off)
    }

    @Test func menuReflectsDisabledPreference() {
        let (sut, _, overlay) = makeSUT(overlayEnabled: false)
        #expect(sut.overlayItem.state == .off)
        #expect(overlay.windows.isEmpty)
    }

    @Test func toggleOverlayUpdatesPreferenceOverlayAndMenu() {
        let (sut, prefs, overlay) = makeSUT()
        #expect(sut.overlayItem.state == .on)
        sut.toggleOverlay()
        #expect(!prefs.overlayEnabled)
        #expect(!overlay.isEnabled)
        #expect(overlay.windows.isEmpty)
        #expect(sut.overlayItem.state == .off)
        #expect(confirm.calls == 0)
    }

    @Test func systemBackgroundDisablesOverlayAndPersistsMenuState() {
        let (sut, prefs, overlay) = makeSUT()
        prefs.showMenuBarIcon = false
        factory.made[0].delaysHide = true
        sut.disableOverlayForSystemBackground()
        #expect(!factory.made[0].isShown)
        #expect(prefs.showMenuBarIcon)
        #expect(sut.iconMenuItem.state == .on)
        #expect(backgroundAlert.calls == 1)
        sut.disableOverlayForSystemBackground()
        #expect(backgroundAlert.calls == 1)
        #expect(!prefs.overlayEnabled)
        #expect(!overlay.isEnabled)
        #expect(overlay.windows.isEmpty)
        #expect(sut.overlayItem.state == .off)
        #expect(confirm.calls == 0)
    }

    @Test func cancelHidingIconRestoresAccess() {
        let (sut, prefs, overlay) = makeSUT()
        confirm.answer = false
        sut.toggleMenuBarIcon()
        #expect(confirm.calls == 1)
        #expect(prefs.showMenuBarIcon)
        #expect(sut.iconMenuItem.state == .on)
        #expect(overlay.isEnabled)
    }

    @Test func enablingOverlayTurnsOnWithoutDialog() {
        let (sut, prefs, overlay) = makeSUT(overlayEnabled: false)
        sut.toggleOverlay()
        #expect(confirm.calls == 0)
        #expect(prefs.overlayEnabled)
        #expect(overlay.windows.count == 1)
        #expect(sut.overlayItem.state == .on)
    }

    @Test func toggleLoginItemEnables() {
        let (sut, _, _) = makeSUT()
        sut.toggleLoginItem()
        #expect(login.state == .enabled)
        #expect(sut.loginMenuItem.state == .on)
        #expect(sut.loginMenuItem.title == L10n.launchAtLogin)
    }

    @Test func loginItemFailureIsShown() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        #expect(login.state == .disabled)
        #expect(sut.loginMenuItem.state == .off)
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginFailed)
    }

    @Test func loginItemSuccessClearsFailure() {
        let (sut, _, _) = makeSUT()
        login.shouldFail = true
        sut.toggleLoginItem()
        login.shouldFail = false
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == L10n.launchAtLogin)
        #expect(sut.loginMenuItem.state == .on)
    }

    @Test func menuWillOpenResyncsExternalChanges() {
        let (sut, _, _) = makeSUT()
        login.state = .enabled  // The user changed the login item in System Settings.
        sut.menuWillOpen(sut.menu)
        #expect(sut.loginMenuItem.state == .on)
    }

    @Test func loginItemPendingApprovalIsShown() {
        let (sut, _, _) = makeSUT()
        login.stateAfterEnable = .requiresApproval
        sut.toggleLoginItem()
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginNeedsApproval)
        #expect(sut.loginMenuItem.state == .off)
    }

    @Test func clickingWhilePendingOpensSettings() {
        let (sut, _, _) = makeSUT()
        login.state = .requiresApproval
        sut.toggleLoginItem()
        #expect(login.openedSettings == 1)
        #expect(login.state == .requiresApproval)
    }

    @Test func menuWillOpenShowsPendingApproval() {
        let (sut, _, _) = makeSUT()
        login.state = .requiresApproval
        sut.menuWillOpen(sut.menu)
        #expect(sut.loginMenuItem.title == L10n.launchAtLoginNeedsApproval)
    }
}
