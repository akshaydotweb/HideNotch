import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private let confirmHidingIcon: @MainActor () -> Bool
    private let informSystemBackground: @MainActor () -> Void
    private let informDisallowedIcon: @MainActor () -> Void
    private(set) var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: L10n.hideNotch, action: #selector(toggleOverlay), keyEquivalent: "")
    let cornersMenuItem = NSMenuItem(title: L10n.roundedScreenCorners, action: #selector(toggleRoundedCorners), keyEquivalent: "")
    let screensWithoutNotchMenuItem = NSMenuItem(title: L10n.displaysWithoutNotch, action: #selector(toggleScreensWithoutNotch), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLoginItem), keyEquivalent: "")
    let iconMenuItem = NSMenuItem(title: L10n.showMenuBarIcon, action: #selector(toggleMenuBarIcon), keyEquivalent: "")

    public init(
        preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling,
        confirmHidingIcon: @escaping @MainActor () -> Bool = StatusItemController.explainHiddenIcon,
        informSystemBackground: @escaping @MainActor () -> Void = StatusItemController.explainSystemBackground,
        informDisallowedIcon: @escaping @MainActor () -> Void = StatusItemController.explainDisallowedIcon
    ) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        self.confirmHidingIcon = confirmHidingIcon
        self.informSystemBackground = informSystemBackground
        self.informDisallowedIcon = informDisallowedIcon
        super.init()

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        for item in [overlayItem, cornersMenuItem, screensWithoutNotchMenuItem, loginMenuItem, iconMenuItem, quitItem] {
            item.target = self
        }
        menu.addItem(overlayItem)
        menu.addItem(cornersMenuItem)
        menu.addItem(screensWithoutNotchMenuItem)
        menu.addItem(loginMenuItem)
        menu.addItem(iconMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.delegate = self
        syncMenuState()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NotchIcon.menuBarImage()
        item.menu = menu
        statusItem = item
        syncMenuState()
    }

    @objc func toggleRoundedCorners() {
        preferences.roundedCornersEnabled.toggle()
        overlay.roundedCornersEnabled = preferences.roundedCornersEnabled
        syncMenuState()
    }

    @objc func toggleScreensWithoutNotch() {
        preferences.screensWithoutNotchEnabled.toggle()
        overlay.screensWithoutNotchEnabled = preferences.screensWithoutNotchEnabled
        syncMenuState()
    }

    @objc func toggleMenuBarIcon() {
        preferences.showMenuBarIcon.toggle()
        syncMenuState()
        if !preferences.showMenuBarIcon && !confirmHidingIcon() {
            restoreMenuBarIcon()
        }
    }

    /// Reopening the running app restores access to its controls.
    public func restoreMenuBarIcon() {
        preferences.showMenuBarIcon = true
        syncMenuState()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        syncMenuState()
    }

    /// macOS doesn't expose "Allow in the Menu Bar", but a disallowed icon's window never becomes visible.
    public func checkIconVisibility(after delay: Duration = .seconds(1)) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, self.preferences.showMenuBarIcon,
                  let window = self.statusItem?.button?.window,
                  !window.occlusionState.contains(.visible) else { return }
            self.informDisallowedIcon()
        }
    }

    @objc func toggleOverlay() {
        let enable = !preferences.overlayEnabled
        preferences.overlayEnabled = enable
        overlay.isEnabled = enable
        syncMenuState()
    }

    /// Stops hiding the notch when the system background would cover the overlay.
    public func disableOverlayForSystemBackground() {
        guard overlay.isEnabled else { return }
        preferences.overlayEnabled = false
        overlay.disableImmediately()
        restoreMenuBarIcon()
        informSystemBackground()
    }

    public static func explainSystemBackground() {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = L10n.systemBackgroundAlertTitle
        alert.informativeText = L10n.systemBackgroundAlertMessage
        alert.addButton(withTitle: L10n.hiddenIconAlertConfirm)
        alert.runModal()
    }

    public static func explainDisallowedIcon() {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = L10n.disallowedIconAlertTitle
        alert.informativeText = L10n.disallowedIconAlertMessage
        alert.addButton(withTitle: L10n.disallowedIconAlertOpenSettings)
        alert.addButton(withTitle: L10n.hiddenIconAlertConfirm)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Activates the (accessory) app before presenting the alert, so it doesn't appear behind other windows.
    public static func explainHiddenIcon() -> Bool {
        NSApplication.shared.activate()
        let alert = NSAlert()
        alert.messageText = L10n.hiddenIconAlertTitle
        alert.informativeText = L10n.hiddenIconAlertMessage
        alert.addButton(withTitle: L10n.hiddenIconAlertConfirm)
        alert.addButton(withTitle: L10n.hiddenIconAlertCancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc func toggleLoginItem() {
        if loginItem.state == .requiresApproval {
            loginItem.openSystemSettings()
            syncMenuState()
            return
        }
        do {
            try loginItem.setEnabled(loginItem.state != .enabled)
            loginItemFailed = false
        } catch {
            loginItemFailed = true
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        syncMenuState()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func syncMenuState() {
        cornersMenuItem.state = preferences.roundedCornersEnabled ? .on : .off
        screensWithoutNotchMenuItem.state = preferences.screensWithoutNotchEnabled ? .on : .off
        iconMenuItem.state = preferences.showMenuBarIcon ? .on : .off
        statusItem?.isVisible = preferences.showMenuBarIcon
        overlayItem.state = preferences.overlayEnabled ? .on : .off
        loginMenuItem.state = loginItem.state == .enabled ? .on : .off
        if loginItemFailed {
            loginMenuItem.title = L10n.launchAtLoginFailed
        } else if loginItem.state == .requiresApproval {
            loginMenuItem.title = L10n.launchAtLoginNeedsApproval
        } else {
            loginMenuItem.title = L10n.launchAtLogin
        }
    }
}
