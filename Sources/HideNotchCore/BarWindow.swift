import AppKit

@MainActor
public protocol BarWindowHosting: AnyObject {
    var frame: CGRect { get }
    func show(at rect: CGRect, menuBarHeight: CGFloat, roundedCornersEnabled: Bool)
    func hide()
}

public final class BarWindow: NSWindow, BarWindowHosting {
    /// One below the system menu bar so menu titles and status items draw on top.
    public static let barLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)

    public init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        backgroundColor = .clear
        isOpaque = false
        animationBehavior = .none
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

    public func show(at rect: CGRect, menuBarHeight: CGFloat, roundedCornersEnabled: Bool = true) {
        let wasVisible = isVisible
        let mask = contentView as? ScreenMaskView
        mask?.menuBarHeight = menuBarHeight
        mask?.setRoundedCornersEnabled(roundedCornersEnabled, animated: wasVisible)
        if !wasVisible { mask?.revealProgress = 0 }
        setFrame(rect, display: true)
        orderFrontRegardless()
        if !wasVisible { mask?.animateReveal() }
    }

    public func hide() {
        orderOut(nil)
    }
}

/// Paints the menu bar and the area outside the rounded desktop black.
final class ScreenMaskView: NSView {
    static let cornerRadius: CGFloat = 16

    private(set) var roundedCornersEnabled = true
    private(set) var maskAnimation: ScreenMaskAnimation?

    var revealProgress: CGFloat = 1 {
        didSet { needsDisplay = true }
    }

    var displayedCornerRadius: CGFloat = cornerRadius {
        didSet { needsDisplay = true }
    }

    func setRoundedCornersEnabled(_ enabled: Bool, animated: Bool) {
        guard enabled != roundedCornersEnabled || !animated else { return }
        roundedCornersEnabled = enabled
        maskAnimation?.stop()
        maskAnimation = nil
        let targetRadius = enabled ? Self.cornerRadius : 0
        guard animated else {
            displayedCornerRadius = targetRadius
            return
        }
        animate(to: targetRadius)
    }

    func animateReveal() {
        animate(to: roundedCornersEnabled ? Self.cornerRadius : 0)
    }

    private func animate(to targetRadius: CGFloat) {
        maskAnimation?.stop()
        let animation = ScreenMaskAnimation(view: self, targetRadius: targetRadius)
        maskAnimation = animation
        animation.start()
    }

    var menuBarHeight: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let revealHeight = bounds.height * revealProgress
        context.clip(to: CGRect(x: bounds.minX, y: bounds.maxY - revealHeight,
                                width: bounds.width, height: revealHeight))

        let desktop = CGRect(
            x: bounds.minX, y: bounds.minY,
            width: bounds.width, height: max(0, bounds.height - menuBarHeight))
        let mask = CGMutablePath()
        mask.addRect(bounds)
        let radius = displayedCornerRadius
        mask.addRoundedRect(in: desktop, cornerWidth: radius, cornerHeight: radius)
        context.addPath(mask)
        context.setFillColor(NSColor.black.cgColor)
        context.drawPath(using: .eoFill)
    }
}

final class ScreenMaskAnimation: NSAnimation {
    private weak var view: ScreenMaskView?
    private let startRadius: CGFloat
    private let targetRadius: CGFloat
    private let startRevealProgress: CGFloat

    @MainActor init(view: ScreenMaskView, targetRadius: CGFloat) {
        self.view = view
        self.startRadius = view.displayedCornerRadius
        self.targetRadius = targetRadius
        self.startRevealProgress = view.revealProgress
        super.init(duration: 0.25, animationCurve: .easeInOut)
        animationBlockingMode = .nonblocking
        frameRate = 60
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            // Nonblocking NSAnimation updates run on the main thread.
            let view = view
            let progress = CGFloat(currentValue)
            let radius = startRadius + (targetRadius - startRadius) * progress
            let reveal = startRevealProgress + (1 - startRevealProgress) * progress
            MainActor.assumeIsolated {
                view?.displayedCornerRadius = radius
                view?.revealProgress = reveal
            }
        }
    }
}
