import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct BarWindowTests {
    @Test func keepsRequestedFrameOverMenuBar() {
        // AppKit must not move the overlay below the menu bar onto app title bars.
        let window = BarWindow()
        let rect = NSRect(x: 0, y: 1130, width: 1800, height: 39)
        #expect(window.constrainFrameRect(rect, to: NSScreen.main) == rect)
    }

    @Test func sitsAboveAppPanelsButBelowMissionControl() {
        let level = BarWindow().level
        #expect(level > .modalPanel)
        #expect(level.rawValue < 14)
    }

    @Test func isTransparentAndClickThrough() {
        let window = BarWindow()
        #expect(window.backgroundColor == .clear)
        #expect(!window.isOpaque)
        #expect(window.animationBehavior == .none)
        #expect(window.contentView is ScreenMaskView)
        #expect(!window.hasShadow)
        #expect(window.ignoresMouseEvents)
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func cannotBeHiddenByHideOthers() {
        // Other apps’ Hide Others command must not hide the overlay.
        #expect(!BarWindow().canHide)
    }

    @Test func joinsAllSpacesButNotFullScreen() {
        let behavior = BarWindow().collectionBehavior
        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.stationary))
        #expect(behavior.contains(.ignoresCycle))
        #expect(!behavior.contains(.fullScreenAuxiliary))
    }

    @Test func screenMaskCoversOnlyTheTopAndBottomEdges() throws {
        let mask = ScreenMask()
        defer { mask.hide() }
        let screen = CGRect(x: 100, y: 0, width: 1800, height: 1169)
        mask.show(at: screen, menuBarHeight: 39, roundedCornersEnabled: true, animated: false)
        #expect(mask.frame == screen)
        #expect(mask.pieces.map(\.frame) == [
            CGRect(x: 100, y: 1114, width: 1800, height: 55),
            CGRect(x: 100, y: 0, width: 1800, height: 16),
        ])
        // Each piece draws its part of the whole screen's mask.
        let top = try #require(mask.pieces[0].contentView as? ScreenMaskView)
        #expect(top.canvas == CGRect(x: 0, y: -1114, width: 1800, height: 1169))
    }

    @Test func showMovesAndHideOrdersOut() {
        let window = BarWindow()
        let rect = CGRect(x: 0, y: 1130, width: 1800, height: 39)
        window.show(at: rect, menuBarHeight: 39)
        #expect(window.frame == rect)
        #expect(window.isVisible)
        window.hide()
        #expect(!window.isVisible)
    }

    @Test func radiusAnimationInterpolatesAndReversesWithoutJumping() throws {
        let view = ScreenMaskView()
        view.setRoundedCornersEnabled(false, animated: false)
        #expect(view.displayedCornerRadius == 0)

        view.setRoundedCornersEnabled(true, animated: true)
        let growing = try #require(view.maskAnimation)
        growing.stop()
        growing.currentProgress = 0.5
        let intermediateRadius = view.displayedCornerRadius
        #expect(intermediateRadius > 0)
        #expect(intermediateRadius < ScreenMaskView.cornerRadius)

        view.setRoundedCornersEnabled(true, animated: true)
        #expect(view.maskAnimation === growing)
        #expect(view.displayedCornerRadius == intermediateRadius)

        view.setRoundedCornersEnabled(false, animated: true)
        let shrinking = try #require(view.maskAnimation)
        shrinking.stop()
        #expect(view.displayedCornerRadius == intermediateRadius)
        shrinking.currentProgress = 1
        #expect(view.displayedCornerRadius == 0)

        view.setRoundedCornersEnabled(true, animated: true)
        let finishing = try #require(view.maskAnimation)
        finishing.stop()
        finishing.currentProgress = 1
        #expect(view.displayedCornerRadius == ScreenMaskView.cornerRadius)
    }

    @Test func restoringWindowSkipsRevealAndCompletesInterruptedAnimation() throws {
        let window = BarWindow()
        defer { window.hide() }
        let rect = CGRect(x: 0, y: 0, width: 100, height: 1000)
        window.show(at: rect, menuBarHeight: 40)
        let view = try #require(window.contentView as? ScreenMaskView)
        window.hide()
        window.show(at: rect, menuBarHeight: 40, animated: false)
        #expect(window.isVisible)
        #expect(window.frame == rect)
        #expect(window.animationBehavior == .none)
        #expect(view.maskAnimation == nil)
        #expect(view.revealProgress == 1)
        #expect(view.displayedCornerRadius == ScreenMaskView.cornerRadius)
    }

    @Test func openingRevealsMaskFromTopWithoutMovingWindowOrRestartingOnRefresh() throws {
        let window = BarWindow()
        defer { window.hide() }
        let rect = CGRect(x: 0, y: 0, width: 100, height: 1000)
        window.show(at: rect, menuBarHeight: 40)
        let view = try #require(window.contentView as? ScreenMaskView)
        let animation = try #require(view.maskAnimation)
        animation.stop()
        #expect(view.revealProgress == 0)

        let context = try #require(CGContext(
            data: nil, width: 100, height: 1000, bitsPerComponent: 8, bytesPerRow: 400,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setShouldAntialias(false)
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        func draw() {
            context.saveGState()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
        }
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(999 - y) * 400 + x * 4 + 3] }

        draw()
        #expect(alpha(50, 990) == 0)
        #expect(alpha(0, 0) == 0)
        animation.currentProgress = 0.5
        draw()
        #expect(alpha(50, 990) == 255)
        // The corner sits directly below the moving strip, with its full radius.
        #expect(alpha(50, 987) == 0)
        #expect(alpha(0, 987) == 255)
        #expect(alpha(3, 984) == 255)
        #expect(alpha(50, 965) == 0)
        #expect(alpha(0, 959) == 0)
        #expect(alpha(3, 3) == 0)
        #expect(view.displayedCornerRadius > 0 && view.displayedCornerRadius < ScreenMaskView.cornerRadius)
        #expect(window.frame == rect)

        window.show(at: rect, menuBarHeight: 40)
        #expect(view.maskAnimation === animation)
        #expect(view.revealProgress > 0 && view.revealProgress < 1)
        animation.currentProgress = 1
        draw()
        #expect(alpha(0, 0) == 255)
        #expect(alpha(3, 3) == 255)
        #expect(alpha(50, 40) == 0)
        #expect(view.revealProgress == 1)

        view.animateReveal(visible: false)
        let reverse = try #require(view.maskAnimation)
        reverse.stop()
        reverse.currentProgress = 0.5
        draw()
        #expect(alpha(50, 987) == 0)
        #expect(alpha(0, 987) == 255)
        #expect(alpha(3, 984) == 255)
        reverse.currentProgress = 1
        draw()
        #expect(alpha(50, 990) == 0)
        #expect(alpha(0, 0) == 0)
    }

    @Test func hidingReversesRevealAndOrdersOutOnlyAfterCompletion() throws {
        let window = BarWindow()
        defer { window.hide() }
        window.show(at: CGRect(x: 0, y: 0, width: 100, height: 1000), menuBarHeight: 40)
        let view = try #require(window.contentView as? ScreenMaskView)
        let opening = try #require(view.maskAnimation)
        opening.stop()
        opening.currentProgress = 1

        var completed = false
        window.hide(animated: true) { completed = true }
        let closing = try #require(view.maskAnimation)
        #expect(closing.duration == 0.6)
        #expect(closing.runLoopModesForAnimating?.contains(.modalPanel) == true)
        closing.stop()
        closing.currentProgress = 0.5
        #expect(window.isVisible)
        #expect(!completed)
        #expect(view.revealProgress > 0 && view.revealProgress < 1)
        #expect(view.displayedCornerRadius > 0 && view.displayedCornerRadius < ScreenMaskView.cornerRadius)
        closing.currentProgress = 1
        #expect(view.revealProgress == 0)
        #expect(view.displayedCornerRadius == 0)
        #expect(!window.isVisible)
        #expect(completed)
    }

    @Test func showingDuringExitReversesWithoutJumpingOrHidingLater() throws {
        let window = BarWindow()
        defer { window.hide() }
        let rect = CGRect(x: 0, y: 0, width: 100, height: 1000)
        window.show(at: rect, menuBarHeight: 40)
        let view = try #require(window.contentView as? ScreenMaskView)
        let opening = try #require(view.maskAnimation)
        opening.stop()
        opening.currentProgress = 1
        var hidden = false
        window.hide(animated: true) { hidden = true }
        let closing = try #require(view.maskAnimation)
        closing.stop()
        closing.currentProgress = 0.5
        let intermediate = view.revealProgress
        window.show(at: rect, menuBarHeight: 40)
        #expect(view.revealProgress == intermediate)
        let reopening = try #require(view.maskAnimation)
        #expect(reopening !== closing)
        reopening.stop()
        reopening.currentProgress = 1
        #expect(window.isVisible)
        #expect(!hidden)
        #expect(view.revealProgress == 1)
    }

    @Test(arguments: [true, false])
    func maskKeepsMenuBarBlackAndDrawsCornersOnlyWhenEnabled(roundedCornersEnabled: Bool) throws {
        let context = try #require(CGContext(
            data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setShouldAntialias(false)
        let view = ScreenMaskView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.menuBarHeight = 20
        view.setRoundedCornersEnabled(roundedCornersEnabled, animated: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()

        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        // Bitmap rows run top to bottom; AppKit coordinates run bottom to top.
        func pixelOffset(_ x: Int, _ y: Int) -> Int { (99 - y) * 400 + x * 4 }
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[pixelOffset(x, y) + 3] }

        #expect(alpha(50, 90) == 255)
        for x in [0, 99] {
            #expect(alpha(x, 79) == (roundedCornersEnabled ? 255 : 0))
            #expect(alpha(x, 0) == (roundedCornersEnabled ? 255 : 0))
            #expect(alpha(x, 40) == 0)
        }
        #expect(alpha(50, 40) == 0)
        #expect(alpha(16, 79) == 0)
        #expect(alpha(50, 0) == 0)
        // These points straddle the arc of a 16-point bottom-left corner.
        #expect(alpha(3, 3) == (roundedCornersEnabled ? 255 : 0))
        #expect(alpha(7, 7) == 0)
        for channel in 0..<3 {
            #expect(pixels[pixelOffset(50, 90) + channel] == 0)
        }
    }
}
