import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let overlay = OverlayController(screens: SystemScreens(), makeWindow: { ScreenMask() },
                                            onEnable: { MenuBarBackground.disable() })
    private let updates = Updater()
    private let wallpaper = WallpaperPainter()
    private var statusController: StatusItemController?
    private var menuBarBackgroundMonitor: Timer?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // The "…" menu's shortcuts only work while it is open; the main menu handles them while the panel is key.
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        NSApplication.shared.mainMenu = NSMenu()
        NSApplication.shared.mainMenu?.addItem(appMenuItem)

        let status = StatusItemController(preferences: preferences, overlay: overlay, loginItem: SystemLoginItem(),
                                          updates: updates,
                                          paintWallpaper: { [wallpaper] in wallpaper.sync($0, completion: $1) })
        status.install()
        status.applyPreferences()
        status.enableLoginItemOnFirstLaunch()
        status.checkIconVisibility()
        status.showHint()
        statusController = status
        updates.start()

        // SkyLight's private notification does not reliably arrive across processes.
        // Read the setting while enabled rather than overriding a user's later change.
        menuBarBackgroundMonitor = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.monitor() }
        }
        // Lets macOS batch the wakeups with other timers.
        menuBarBackgroundMonitor?.tolerance = 0.5
        if let menuBarBackgroundMonitor {
            RunLoop.main.add(menuBarBackgroundMonitor, forMode: .common)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(layoutChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(sessionInactive),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(sessionActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        // loginwindow's lock notifications are not a documented AppKit API.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked),
                                name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked),
                                name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    /// Runs every second: catches wallpaper changes, crowded menu bars, and the system menu bar background.
    private func monitor() {
        statusController?.syncWallpaper()
        let frames = overlay.isEnabled ? overlay.windows.map(\.frame) : []
        let crowded = MenuBarCrowding.crowded(frames)
        overlay.updateCrowding { frame in zip(frames, crowded).first { $0.0 == frame }?.1 ?? false }
        statusController?.updateWallpaperWarning(crowded: crowded.contains(true))
        guard overlay.isEnabled, MenuBarBackground.isEnabled == true else { return }
        statusController?.disableOverlayForSystemBackground()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusController?.restoreMenuBarIcon()
        // An existing status item keeps reporting itself visible after "Allow in the Menu Bar" is turned
        // off. A new one picks up the current setting.
        statusController?.install()
        statusController?.checkIconVisibility()
        return false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Start after returning terminateLater, so even an immediate completion can reply safely.
        Task { @MainActor in
            let hideOverlay: @MainActor () -> Void = { [overlay] in
                overlay.isEnabled = false
                overlay.hideAll {
                    sender.reply(toApplicationShouldTerminate: true)
                }
            }
            // The original wallpapers go back first, so the overlay's animation shows against them.
            if let statusController {
                statusController.restoreWallpaper(completion: hideOverlay)
            } else {
                hideOverlay()
            }
        }
        return .terminateLater
    }

    private var screenIsLocked = false
    private var sessionIsActive = true

    @objc private func screenLocked(_ notification: Notification) {
        screenIsLocked = true
        overlay.suspend()
    }

    @objc private func screenUnlocked(_ notification: Notification) {
        screenIsLocked = false
        if sessionIsActive { overlay.resume() }
    }

    @objc private func sessionInactive(_ notification: Notification) {
        sessionIsActive = false
        overlay.suspend()
    }

    @objc private func sessionActive(_ notification: Notification) {
        sessionIsActive = true
        if !screenIsLocked { overlay.resume() }
    }

    @objc private func layoutChanged(_ notification: Notification) {
        overlay.refresh()
        statusController?.syncWallpaper()
        // Screens may not have settled yet (e.g. right after wake); refresh again shortly after.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.overlay.refresh()
            self?.statusController?.syncWallpaper()
        }
    }
}
