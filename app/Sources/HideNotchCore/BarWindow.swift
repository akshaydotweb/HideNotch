import AppKit

@MainActor
public protocol BarWindowHosting: AnyObject {
    var frame: CGRect { get }
    func show(at rect: CGRect, menuBarHeight: CGFloat, roundedCornersEnabled: Bool, animated: Bool)
    func hide()
    func hide(animated: Bool, completion: @escaping @MainActor () -> Void)
}

public extension BarWindowHosting {
    func hide(animated: Bool, completion: @escaping @MainActor () -> Void) {
        hide()
        completion()
    }
}

/// Covers one screen with two windows: the menu bar strip with the corners below it, and a strip
/// with the bottom corners. A full-screen window would keep Mission Control from showing other
/// windows' previews.
public final class ScreenMask: BarWindowHosting {
    let pieces = [BarWindow(), BarWindow()]
    public private(set) var frame: CGRect = .zero

    public init() {}

    public func show(at rect: CGRect, menuBarHeight: CGFloat, roundedCornersEnabled: Bool, animated: Bool) {
        frame = rect
        let corner = ScreenMaskView.cornerRadius
        let top = menuBarHeight + corner
        let rects = [
            CGRect(x: rect.minX, y: rect.maxY - top, width: rect.width, height: top),
            CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: corner),
        ]
        for (piece, pieceRect) in zip(pieces, rects) {
            piece.show(at: pieceRect, screen: rect, menuBarHeight: menuBarHeight,
                       roundedCornersEnabled: roundedCornersEnabled, animated: animated)
        }
    }

    public func hide() {
        for piece in pieces { piece.hide() }
    }

    public func hide(animated: Bool, completion: @escaping @MainActor () -> Void) {
        var remaining = pieces.count
        for piece in pieces {
            piece.hide(animated: animated) {
                remaining -= 1
                if remaining == 0 { completion() }
            }
        }
    }
}

public final class BarWindow: NSWindow {
    private var isHiding = false
    private var hideCompletions: [@MainActor () -> Void] = []
    /// Above app windows and their panels, but below Mission Control, whose Spaces bar sits at 14.
    public static let barLevel = NSWindow.Level(rawValue: 13)

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
        // .stationary keeps it in place when Show Desktop moves the windows aside.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Keeps the bar out of window captures, like Mission Control's Space previews and screenshots.
        sharingType = .none
    }

    /// AppKit otherwise pushes the window below the menu bar, over app title bars.
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Shows the part of the screen mask that falls inside `rect`. Without a `screen`, the window is the screen.
    public func show(at rect: CGRect, screen: CGRect? = nil, menuBarHeight: CGFloat,
                     roundedCornersEnabled: Bool = true, animated: Bool = true) {
        let wasVisible = isVisible
        let wasHiding = isHiding
        isHiding = false
        hideCompletions.removeAll()
        let mask = contentView as? ScreenMaskView
        mask?.menuBarHeight = menuBarHeight
        mask?.canvas = screen.map { $0.offsetBy(dx: -rect.minX, dy: -rect.minY) }
        mask?.setRoundedCornersEnabled(roundedCornersEnabled, animated: animated && wasVisible)
        if !animated {
            mask?.revealProgress = 1
        } else if !wasVisible {
            mask?.revealProgress = 0
            mask?.displayedCornerRadius = 0
        }
        setFrame(rect, display: true)
        if !wasVisible { orderFrontRegardless() }
        if animated && (!wasVisible || wasHiding) { mask?.animateReveal() }
    }

    public func hide() {
        (contentView as? ScreenMaskView)?.maskAnimation?.stop()
        isHiding = false
        orderOut(nil)
        let completions = hideCompletions
        hideCompletions.removeAll()
        completions.forEach { $0() }
    }

    public func hide(animated: Bool, completion: @escaping @MainActor () -> Void) {
        guard animated, isVisible, let mask = contentView as? ScreenMaskView else {
            hide()
            completion()
            return
        }
        hideCompletions.append(completion)
        guard !isHiding else { return }
        isHiding = true
        mask.animateReveal(visible: false) { [weak self] in
            self?.hide()
        }
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

    func animateReveal(visible: Bool = true, completion: @escaping @MainActor () -> Void = {}) {
        animate(to: visible && roundedCornersEnabled ? Self.cornerRadius : 0,
                revealProgress: visible ? 1 : 0, completion: completion)
    }

    private func animate(to targetRadius: CGFloat, revealProgress: CGFloat = 1,
                         completion: @escaping @MainActor () -> Void = {}) {
        maskAnimation?.stop()
        let animation = ScreenMaskAnimation(view: self, targetRadius: targetRadius,
                                            targetRevealProgress: revealProgress, completion: completion)
        maskAnimation = animation
        animation.start()
    }

    var menuBarHeight: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    /// The whole screen in view coordinates, when the view shows only part of it.
    var canvas: CGRect? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(self.bounds)
        let bounds = canvas ?? self.bounds
        let desktop = CGRect(
            x: bounds.minX, y: bounds.minY,
            width: bounds.width, height: max(0, bounds.height - menuBarHeight))
        context.setFillColor(NSColor.black.cgColor)
        func drawMask(radius: CGFloat) {
            let mask = CGMutablePath()
            mask.addRect(bounds)
            mask.addRoundedRect(in: desktop, cornerWidth: radius, cornerHeight: radius)
            context.addPath(mask)
            context.drawPath(using: .eoFill)
        }

        // Slide the strip and its upper corners together, keeping their shape intact.
        let topHeight = menuBarHeight + Self.cornerRadius
        let topRadius = revealProgress < 1
            ? (roundedCornersEnabled ? Self.cornerRadius : 0)
            : displayedCornerRadius
        context.saveGState()
        context.clip(to: CGRect(x: bounds.minX, y: bounds.maxY - topHeight,
                                width: bounds.width, height: topHeight))
        context.translateBy(x: 0, y: topHeight * (1 - revealProgress))
        drawMask(radius: topRadius)
        context.restoreGState()

        context.saveGState()
        context.clip(to: CGRect(x: bounds.minX, y: bounds.minY,
                                width: bounds.width, height: Self.cornerRadius))
        drawMask(radius: displayedCornerRadius)
        context.restoreGState()
    }
}

final class ScreenMaskAnimation: NSAnimation {
    static let transitionDuration: TimeInterval = 0.6
    private weak var view: ScreenMaskView?
    private let startRadius: CGFloat
    private let targetRadius: CGFloat
    private let startRevealProgress: CGFloat
    private let targetRevealProgress: CGFloat
    private var completion: (@MainActor () -> Void)?

    @MainActor init(view: ScreenMaskView, targetRadius: CGFloat, targetRevealProgress: CGFloat,
                    completion: @escaping @MainActor () -> Void) {
        self.view = view
        self.startRadius = view.displayedCornerRadius
        self.targetRadius = targetRadius
        self.startRevealProgress = view.revealProgress
        self.targetRevealProgress = targetRevealProgress
        self.completion = completion
        super.init(duration: Self.transitionDuration, animationCurve: .easeInOut)
        animationBlockingMode = .nonblocking
        frameRate = 60
    }

    override var runLoopModesForAnimating: [RunLoop.Mode]? {
        [.default, .modalPanel, .eventTracking]
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
            let reveal = startRevealProgress + (targetRevealProgress - startRevealProgress) * progress
            let completion = currentProgress >= 1 ? self.completion : nil
            if currentProgress >= 1 { self.completion = nil }
            MainActor.assumeIsolated {
                view?.displayedCornerRadius = radius
                view?.revealProgress = reveal
                completion?()
            }
        }
    }
}
