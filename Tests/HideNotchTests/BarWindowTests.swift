import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct BarWindowTests {
    @Test func keepsRequestedFrameOverMenuBar() {
        // 回归：AppKit 默认会把窗口挪到菜单栏下方，压住应用标题栏
        let window = BarWindow()
        let rect = NSRect(x: 0, y: 1130, width: 1800, height: 39)
        #expect(window.constrainFrameRect(rect, to: NSScreen.main) == rect)
    }

    @Test func sitsJustBelowMenuBarLevel() {
        #expect(BarWindow().level.rawValue == NSWindow.Level.mainMenu.rawValue - 1)
    }

    @Test func isTransparentAndClickThrough() {
        let window = BarWindow()
        #expect(window.backgroundColor == .clear)
        #expect(!window.isOpaque)
        #expect(window.contentView is ScreenMaskView)
        #expect(!window.hasShadow)
        #expect(window.ignoresMouseEvents)
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func cannotBeHiddenByHideOthers() {
        // 回归：其他应用 Cmd-Opt-H「隐藏其他」不应把黑条一并隐藏
        #expect(!BarWindow().canHide)
    }

    @Test func joinsAllSpacesButNotFullScreen() {
        let behavior = BarWindow().collectionBehavior
        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.stationary))
        #expect(behavior.contains(.ignoresCycle))
        #expect(!behavior.contains(.fullScreenAuxiliary))
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

    @Test func maskDrawsBlackCornersBelowMenuBarAndLeavesDesktopClear() throws {
        let context = try #require(CGContext(
            data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setShouldAntialias(false)
        let view = ScreenMaskView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.menuBarHeight = 20
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
            #expect(alpha(x, 79) == 255)
            #expect(alpha(x, 0) == 255)
            #expect(alpha(x, 40) == 0)
        }
        #expect(alpha(50, 40) == 0)
        #expect(alpha(16, 79) == 0)
        #expect(alpha(50, 0) == 0)
        // These points straddle the arc of a 16-point bottom-left corner.
        #expect(alpha(3, 3) == 255)
        #expect(alpha(7, 7) == 0)
        for channel in 0..<3 {
            #expect(pixels[pixelOffset(50, 90) + channel] == 0)
        }
    }
}
