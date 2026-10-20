import AppKit
import Observation
import os
import SwiftUI

@MainActor
@Observable
public final class StatusItemController: NSObject, NSPopoverDelegate {
    @ObservationIgnored private static let log = Logger(subsystem: "com.niklasravnsborg.hidenotch", category: "StatusItem")

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let overlay: OverlayController
    @ObservationIgnored private let loginItem: LoginItemControlling
    @ObservationIgnored private let confirmHidingIcon: @MainActor () -> Bool
    @ObservationIgnored private let informSystemBackground: @MainActor () -> Void
    @ObservationIgnored private let informDisallowedIcon: @MainActor () -> Void
    @ObservationIgnored private(set) var statusItem: NSStatusItem?
    @ObservationIgnored let popover = NSPopover()
    @ObservationIgnored private var outsideClickMonitor: Any?
    @ObservationIgnored let updates: UpdateChecker
    private var loginItemFailed = false

    private(set) var isOverlayEnabled = false
    private(set) var isRoundedCornersEnabled = false
    private(set) var isScreensWithoutNotchEnabled = false
    private(set) var isMenuBarIconShown = false
    private(set) var isLaunchAtLoginEnabled = false
    private(set) var launchAtLoginTitle = L10n.launchAtLogin

    public init(
        preferences: Preferences, overlay: OverlayController, loginItem: LoginItemControlling,
        updates: UpdateChecker = UpdateChecker(),
        confirmHidingIcon: @escaping @MainActor () -> Bool = StatusItemController.explainHiddenIcon,
        informSystemBackground: @escaping @MainActor () -> Void = StatusItemController.explainSystemBackground,
        informDisallowedIcon: @escaping @MainActor () -> Void = StatusItemController.explainDisallowedIcon
    ) {
        self.preferences = preferences
        self.overlay = overlay
        self.loginItem = loginItem
        self.updates = updates
        self.confirmHidingIcon = confirmHidingIcon
        self.informSystemBackground = informSystemBackground
        self.informDisallowedIcon = informDisallowedIcon
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let content = NSHostingController(rootView: SettingsView(controller: self))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        syncState()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NotchIcon.menuBarImage()
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        syncState()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // The cooperative activate() is refused while another app is frontmost.
            NSApplication.shared.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // macOS may refuse to activate an accessory app, and then .transient misses clicks in other apps.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.popover.performClose(nil) }
            }
        }
    }

    public func popoverWillShow(_ notification: Notification) {
        syncState()
    }

    public func popoverDidClose(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    func toggleRoundedCorners() {
        preferences.roundedCornersEnabled.toggle()
        overlay.roundedCornersEnabled = preferences.roundedCornersEnabled
        syncState()
    }

    func toggleScreensWithoutNotch() {
        preferences.screensWithoutNotchEnabled.toggle()
        overlay.screensWithoutNotchEnabled = preferences.screensWithoutNotchEnabled
        syncState()
    }

    func toggleMenuBarIcon() {
        popover.close()
        preferences.showMenuBarIcon.toggle()
        syncState()
        if !preferences.showMenuBarIcon && !confirmHidingIcon() {
            restoreMenuBarIcon()
        }
    }

    /// Reopening the running app restores access to its controls.
    public func restoreMenuBarIcon() {
        preferences.showMenuBarIcon = true
        syncState()
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

    func toggleOverlay() {
        let enable = !preferences.overlayEnabled
        preferences.overlayEnabled = enable
        overlay.isEnabled = enable
        syncState()
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

    func toggleLoginItem() {
        if loginItem.state == .requiresApproval {
            loginItem.openSystemSettings()
            syncState()
            return
        }
        do {
            try loginItem.setEnabled(loginItem.state != .enabled)
            loginItemFailed = false
        } catch {
            loginItemFailed = true
            Self.log.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
        syncState()
    }

    func checkForUpdates() {
        popover.close()
        Task { @MainActor in
            let alert = NSAlert()
            var offersDownload = false
            do {
                if let version = try await updates.check() {
                    offersDownload = true
                    alert.messageText = L10n.updateAlertTitle(version)
                    alert.informativeText = L10n.updateAlertMessage(updates.currentVersion)
                    alert.addButton(withTitle: L10n.updateAlertDownload)
                    alert.addButton(withTitle: L10n.updateAlertLater)
                } else {
                    alert.messageText = L10n.upToDateAlertTitle
                    alert.informativeText = L10n.upToDateAlertMessage(updates.currentVersion)
                    alert.addButton(withTitle: L10n.hiddenIconAlertConfirm)
                }
            } catch {
                alert.messageText = L10n.updateFailedAlertTitle
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: L10n.hiddenIconAlertConfirm)
            }
            NSApplication.shared.activate()
            if alert.runModal() == .alertFirstButtonReturn, offersDownload {
                NSWorkspace.shared.open(UpdateChecker.download)
            }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func syncState() {
        isOverlayEnabled = preferences.overlayEnabled
        isRoundedCornersEnabled = preferences.roundedCornersEnabled
        isScreensWithoutNotchEnabled = preferences.screensWithoutNotchEnabled
        isMenuBarIconShown = preferences.showMenuBarIcon
        statusItem?.isVisible = preferences.showMenuBarIcon
        isLaunchAtLoginEnabled = loginItem.state == .enabled
        if loginItemFailed {
            launchAtLoginTitle = L10n.launchAtLoginFailed
        } else if loginItem.state == .requiresApproval {
            launchAtLoginTitle = L10n.launchAtLoginNeedsApproval
        } else {
            launchAtLoginTitle = L10n.launchAtLogin
        }
    }
}
