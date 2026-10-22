import AppKit
import Testing
@testable import HideNotchCore

struct WallpaperPainterTests {
    let canvas = CGSize(width: 3000, height: 2000)
    let wide = CGSize(width: 4000, height: 2000)

    @Test func fillingCropsToCoverTheScreen() {
        let rect = WallpaperPainter.placement(of: wide, in: canvas, scaling: .scaleProportionallyUpOrDown,
                                              allowsClipping: true)
        #expect(rect == CGRect(x: -500, y: 0, width: 4000, height: 2000))
    }

    @Test func fittingLeavesBarsForTheFillColor() {
        let rect = WallpaperPainter.placement(of: wide, in: canvas, scaling: .scaleProportionallyUpOrDown,
                                              allowsClipping: false)
        #expect(rect == CGRect(x: 0, y: 250, width: 3000, height: 1500))
    }

    @Test func stretchingAndCentering() {
        #expect(WallpaperPainter.placement(of: wide, in: canvas, scaling: .scaleAxesIndependently,
                                           allowsClipping: false) == CGRect(origin: .zero, size: canvas))
        #expect(WallpaperPainter.placement(of: CGSize(width: 1000, height: 1000), in: canvas, scaling: .scaleNone,
                                           allowsClipping: false) == CGRect(x: 1000, y: 500, width: 1000, height: 1000))
    }
}

struct WallpaperRenderingTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "HideNotchTests-\(UUID().uuidString)")

    func image(_ color: CGColor) -> CGImage {
        let context = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        return context.makeImage()!
    }

    @Test func dynamicWallpapersKeepEveryImageAndTheirSchedule() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appending(path: "dynamic.heic")
        let destination = try #require(CGImageDestinationCreateWithURL(source as CFURL, "public.heic" as CFString, 2, nil))
        let metadata = CGImageMetadataCreateMutable()
        CGImageMetadataRegisterNamespaceForPrefix(metadata, "http://ns.apple.com/namespace/1.0/" as CFString,
                                                  "apple_desktop" as CFString, nil)
        CGImageMetadataSetValueWithPath(metadata, nil, "apple_desktop:apr" as CFString, "schedule" as CFString)
        CGImageDestinationAddImageAndMetadata(destination, image(CGColor(red: 1, green: 1, blue: 1, alpha: 1)), metadata, nil)
        CGImageDestinationAddImage(destination, image(CGColor(red: 0, green: 0, blue: 1, alpha: 1)), nil)
        #expect(CGImageDestinationFinalize(destination))

        let target = folder.appending(path: "painted.heic")
        let wallpaper = Wallpaper(url: source, options: [.allowClipping: true])
        #expect(WallpaperPainter.render(wallpaper, size: CGSize(width: 40, height: 20), barHeight: 4, cornerRadius: 2, to: target,
                                        folder: folder))

        let painted = try #require(CGImageSourceCreateWithURL(target as CFURL, nil))
        #expect(CGImageSourceGetCount(painted) == 2)
        let tags = try #require(CGImageSourceCopyMetadataAtIndex(painted, 0, nil))
        let schedule = CGImageMetadataCopyStringValueWithPath(tags, nil, "apple_desktop:apr" as CFString)
        #expect(schedule as String? == "schedule")
    }
}
