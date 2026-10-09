import AppKit
import Testing
@testable import HideNotchCore

@MainActor
struct NotchIconTests {
    @Test func menuBarImageIsTemplate18pt() {
        let image = NotchIcon.menuBarImage()
        #expect(image.size == NSSize(width: 18, height: 18))
        #expect(image.isTemplate)
    }

    @Test func appIconPNGHasRequestedPixels() {
        let data = NotchIcon.appIconPNG(pixels: 64)
        let rep = NSBitmapImageRep(data: data)
        #expect(rep?.pixelsWide == 64)
        #expect(rep?.pixelsHigh == 64)
    }

    @Test func appIconShowsOutlineNotchAndScreen() {
        let pixels = 256
        let data = NotchIcon.appIconPNG(pixels: pixels)
        let rep = NSBitmapImageRep(data: data)!

        let side = CGFloat(pixels)
        let square = CGRect(x: 0, y: 0, width: side, height: side)
            .insetBy(dx: side * NotchIcon.AppIconLayout.squareInsetFraction, dy: side * NotchIcon.AppIconLayout.squareInsetFraction)
        let glyphWidth = square.width * NotchIcon.AppIconLayout.glyphWidthFraction
        let glyph = NotchIcon.glyphRect(width: glyphWidth, centeredIn: square)

        // Convert a canvas-space (bottom-left origin, y-up) point to NSBitmapImageRep.colorAt
        // coordinates (top-left origin, y-down) verified empirically for this rendering setup.
        func pixel(at point: CGPoint) -> NSColor {
            let x = Int(point.x)
            let y = pixels - 1 - Int(point.y)
            return rep.colorAt(x: max(0, min(pixels - 1, x)), y: max(0, min(pixels - 1, y)))!
        }
        func brightness(_ color: NSColor) -> CGFloat {
            let c = color.usingColorSpace(.deviceRGB)!
            return (c.redComponent + c.greenComponent + c.blueComponent) / 3
        }

        // The top outline stays dark, with an open screen immediately below it.
        let outlinePoint = CGPoint(x: glyph.minX + glyph.width * 0.25, y: glyph.maxY - glyph.height * 0.04)
        let outlineColor = pixel(at: outlinePoint)
        #expect(brightness(outlineColor) < 0.25)
        #expect(outlineColor.alphaComponent > 0.9)

        let openScreenPoint = CGPoint(x: glyph.minX + glyph.width * 0.2, y: glyph.maxY - glyph.height * 0.18)
        #expect(brightness(pixel(at: openScreenPoint)) > 0.8)

        let notchPoint = CGPoint(x: glyph.midX, y: glyph.maxY - glyph.height * 0.15)
        #expect(brightness(pixel(at: notchPoint)) < 0.25)

        // Well below the notch, inside the "screen" area of the glyph.
        let screenPoint = CGPoint(x: glyph.midX, y: glyph.minY + glyph.height * 0.15)
        #expect(brightness(pixel(at: screenPoint)) > 0.8)

        // Canvas corner, outside the rounded square: transparent.
        let corner = rep.colorAt(x: 2, y: 2)!
        #expect(corner.alphaComponent < 0.1)
    }
}
