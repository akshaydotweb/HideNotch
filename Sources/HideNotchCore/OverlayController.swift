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

/// Keeps one screen mask per notched screen in sync with the current screen layout.
@MainActor
public final class OverlayController {
    private let screens: ScreenProviding
    private let makeWindow: @MainActor () -> BarWindowHosting
    private(set) var windows: [BarWindowHosting] = []

    public var isEnabled = false {
        didSet { refresh() }
    }

    public var roundedCornersEnabled = true {
        didSet { refresh() }
    }

    public init(screens: ScreenProviding, makeWindow: @escaping @MainActor () -> BarWindowHosting) {
        self.screens = screens
        self.makeWindow = makeWindow
    }

    public func refresh() {
        let layouts = isEnabled ? screens.currentScreens().compactMap { screen -> (frame: CGRect, menuBarHeight: CGFloat)? in
            guard let bar = BarGeometry.barRect(for: screen) else { return nil }
            return (screen.frame, bar.height)
        } : []
        while windows.count > layouts.count {
            windows.removeLast().hide()
        }
        while windows.count < layouts.count {
            windows.append(makeWindow())
        }
        for (window, layout) in zip(windows, layouts) {
            window.show(at: layout.frame, menuBarHeight: layout.menuBarHeight,
                        roundedCornersEnabled: roundedCornersEnabled)
        }
    }
}
