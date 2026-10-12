import AppKit

@MainActor
public protocol ScreenProviding {
    func currentScreens() -> [ScreenMetrics]
}

public struct SystemScreens: ScreenProviding {
    public init() {}

    public func currentScreens() -> [ScreenMetrics] {
        NSScreen.screens.map {
            ScreenMetrics(frame: $0.frame, visibleFrame: $0.visibleFrame, safeAreaTop: $0.safeAreaInsets.top)
        }
    }
}

/// Keeps one screen mask per covered screen in sync with the current screen layout.
@MainActor
public final class OverlayController {
    private let screens: ScreenProviding
    private let makeWindow: @MainActor () -> BarWindowHosting
    private let onEnable: @MainActor () -> Void
    private(set) var windows: [BarWindowHosting] = []
    private(set) var isSuspended = false

    public var isEnabled = false {
        didSet {
            if isEnabled && !oldValue { onEnable() }
            refresh()
        }
    }

    public var roundedCornersEnabled = true {
        didSet { refresh() }
    }

    public var screensWithoutNotchEnabled = false {
        didSet { refresh() }
    }

    public init(screens: ScreenProviding, makeWindow: @escaping @MainActor () -> BarWindowHosting,
                onEnable: @escaping @MainActor () -> Void = {}) {
        self.screens = screens
        self.makeWindow = makeWindow
        self.onEnable = onEnable
    }

    public func disableImmediately() {
        let hidingWindows = windows
        windows.removeAll()
        isEnabled = false
        for window in hidingWindows { window.hide() }
    }

    public func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        // Keep the windows and preferences, but remove them from the unlock transition.
        for window in windows { window.hide() }
    }

    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        refresh(animated: false)
    }

    public func refresh(animated: Bool = true) {
        guard !isSuspended else { return }
        guard isEnabled else {
            hideAll(completion: {})
            return
        }
        let layouts = screens.currentScreens().compactMap { screen -> (frame: CGRect, menuBarHeight: CGFloat)? in
            guard let bar = BarGeometry.barRect(
                for: screen, includingScreensWithoutNotch: screensWithoutNotchEnabled) else { return nil }
            return (screen.frame, bar.height)
        }
        while windows.count > layouts.count {
            windows.removeLast().hide()
        }
        while windows.count < layouts.count {
            windows.append(makeWindow())
        }
        for (window, layout) in zip(windows, layouts) {
            window.show(at: layout.frame, menuBarHeight: layout.menuBarHeight,
                        roundedCornersEnabled: roundedCornersEnabled, animated: animated)
        }
    }

    public func hideAll(completion: @escaping @MainActor () -> Void) {
        let hidingWindows = windows
        guard !hidingWindows.isEmpty else {
            completion()
            return
        }
        var remaining = hidingWindows.count
        for window in hidingWindows {
            window.hide(animated: true) { [weak self, weak window] in
                if let self, let window, !self.isEnabled {
                    self.windows.removeAll { $0 === window }
                }
                remaining -= 1
                if remaining == 0 { completion() }
            }
        }
    }
}
