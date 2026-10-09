import AppKit
import os

@MainActor
public final class StatusItemController: NSObject, NSMenuDelegate {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "StatusItem")

    private let preferences: Preferences
    private let overlay: OverlayController
    private let loginItem: LoginItemControlling
    private let confirmHidingIcon: @MainActor () -> Bool
    private(set) var statusItem: NSStatusItem?
    private var loginItemFailed = false

    let menu = NSMenu()
    let overlayItem = NSMenuItem(title: L10n.hideNotch, action: #selector(toggleOverlay), keyEquivalent: "")
    let cornersMenuItem = NSMenuItem(title: L10n.roundedScreenCorners, action: #selector(toggleRoundedCorners), keyEquivalent: "")
    let loginMenuItem = NSMenuItem(title: L10n.launchAtLogin, action: #selector(toggleLoginItem), keyEquivalent: "")
    let iconMenuItem = NSMenuItem(title: L10n.showMenuBarIcon, action: #selector(toggleMenuBarIcon), keyEquivalent: "")

    public init(
        preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling,
        confirmHidingIcon: @escaping @MainActor () -> Bool = StatusItemController.explainHiddenIcon
    ) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        self.confirmHidingIcon = confirmHidingIcon
        super.init()

        let quitItem = NSMenuItem(title: L10n.quit, action: #selector(quit), keyEquivalent: "q")
        for item in [overlayItem, cornersMenuItem, loginMenuItem, iconMenuItem, quitItem] {
            item.target = self
        }
        menu.addItem(overlayItem)
        menu.addItem(cornersMenuItem)
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

    @objc func toggleOverlay() {
        let enable = !preferences.overlayEnabled
        preferences.overlayEnabled = enable
        overlay.isEnabled = enable
        syncMenuState()
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
