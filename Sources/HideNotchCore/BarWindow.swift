import AppKit

@MainActor
public protocol BarWindowHosting: AnyObject {
    var frame: CGRect { get }
    func show(at rect: CGRect, menuBarHeight: CGFloat)
    func hide()
}

public final class BarWindow: NSWindow, BarWindowHosting {
    /// One below the system menu bar so menu titles and status items draw on top.
    public static let barLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)

    public init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        backgroundColor = .clear
        isOpaque = false
        contentView = ScreenMaskView()
        hasShadow = false
        ignoresMouseEvents = true
        // Other apps' Cmd-Opt-H "Hide Others" must not hide the bar permanently.
        canHide = false
        isReleasedWhenClosed = false
        level = Self.barLevel
        // No .fullScreenAuxiliary: the bar must not appear in full-screen spaces.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    /// AppKit otherwise pushes the window below the menu bar, over app title bars.
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public func show(at rect: CGRect, menuBarHeight: CGFloat) {
        (contentView as? ScreenMaskView)?.menuBarHeight = menuBarHeight
        setFrame(rect, display: true)
        orderFrontRegardless()
    }

    public func hide() {
        orderOut(nil)
    }
}

/// Paints the menu bar and the area outside the rounded desktop black.
final class ScreenMaskView: NSView {
    static let cornerRadius: CGFloat = 16

    var menuBarHeight: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        let desktop = CGRect(
            x: bounds.minX, y: bounds.minY,
            width: bounds.width, height: max(0, bounds.height - menuBarHeight))
        let mask = CGMutablePath()
        mask.addRect(bounds)
        mask.addRoundedRect(in: desktop, cornerWidth: Self.cornerRadius, cornerHeight: Self.cornerRadius)
        context.addPath(mask)
        context.setFillColor(NSColor.black.cgColor)
        context.drawPath(using: .eoFill)
    }
}
