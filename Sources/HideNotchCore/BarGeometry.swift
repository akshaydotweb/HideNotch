import CoreGraphics

public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var safeAreaTop: CGFloat

    public init(frame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.safeAreaTop = safeAreaTop
    }
}

public enum BarGeometry {
    /// Rect covering the menu bar and notch, or nil for screens without a notch unless included.
    /// Height takes the larger of menu bar and notch so an auto-hidden menu bar still blends.
    public static func barRect(for m: ScreenMetrics, includingScreensWithoutNotch: Bool = false) -> CGRect? {
        guard m.safeAreaTop > 0 || includingScreensWithoutNotch else { return nil }
        let height = max(m.frame.maxY - m.visibleFrame.maxY, m.safeAreaTop)
        // Without a notch, a hidden menu bar leaves nothing to cover.
        guard height > 0 else { return nil }
        return CGRect(x: m.frame.minX, y: m.frame.maxY - height, width: m.frame.width, height: height)
    }
}
