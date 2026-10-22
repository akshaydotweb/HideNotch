import AppKit
import CryptoKit
import ImageIO
import os
import UniformTypeIdentifiers

/// What the wallpapers should show.
public struct WallpaperTarget: Equatable, Sendable {
    public var active = false
    public var includingScreensWithoutNotch = false
    public var roundedCorners = false

    public init(active: Bool = false, includingScreensWithoutNotch: Bool = false, roundedCorners: Bool = false) {
        self.active = active
        self.includingScreensWithoutNotch = includingScreensWithoutNotch
        self.roundedCorners = roundedCorners
    }
}

/// Paints the black bar into a copy of each covered screen's wallpaper, because macOS Tahoe shows the
/// wallpaper instead of the overlay behind the menu bar once enough windows reach it.
/// Remembers which original each copy replaced, so it can put the originals back.
@MainActor
public final class WallpaperPainter {
    private static let log = Logger(subsystem: "com.niklasravnsborg.hidenotch", category: "WallpaperPainter")
    static let originalsKey = "paintedWallpaperOriginals"
    /// How long macOS takes to show a newly set wallpaper.
    static let swapDelay: Duration = .milliseconds(600)

    private let workspace = NSWorkspace.shared
    private let defaults: UserDefaults
    private let folder: URL
    /// Copies being rendered, with the syncs waiting for them.
    private var rendering: [String: [PendingChanges]] = [:]
    /// What each screen showed at its last sync, so an unchanged screen skips reading its image.
    private var seen: [CGDirectDisplayID: (screen: SeenScreen, paintable: Bool)] = [:]
    private var cachedOriginals: [String: Wallpaper]?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        folder = URL.applicationSupportDirectory.appending(path: "HideNotch/Wallpapers", directoryHint: .isDirectory)
    }

    /// Paints the covered screens while active and restores every other screen showing a painted copy.
    /// Calls `completion` once every change is on screen.
    @discardableResult
    public func sync(_ target: WallpaperTarget, completion: @escaping @MainActor () -> Void = {}) -> WallpaperState {
        let changes = PendingChanges(completion: completion)
        var paintable = true
        for screen in NSScreen.screens {
            guard let current = workspace.desktopImageURL(for: screen) else { continue }
            let id = screen.displayID ?? 0
            let key = SeenScreen(url: current, frame: screen.frame, target: target)
            if rendering.isEmpty, let last = seen[id], last.screen == key {
                paintable = paintable && last.paintable
                continue
            }
            let screenPaintable = sync(screen, showing: current, target: target, changes: changes)
            seen[id] = (key, screenPaintable)
            paintable = paintable && screenPaintable
        }
        changes.seal()
        return WallpaperState(paintable: paintable, settled: changes.isSettled)
    }

    /// Returns false if the screen is covered but its wallpaper can't be painted.
    private func sync(_ screen: NSScreen, showing current: URL, target: WallpaperTarget,
                      changes: PendingChanges) -> Bool {
        guard let bar = BarGeometry.barRect(
                for: ScreenMetrics(frame: screen.frame, visibleFrame: screen.visibleFrame,
                                   safeAreaTop: screen.safeAreaInsets.top),
                includingScreensWithoutNotch: target.includingScreensWithoutNotch) else {
            changes.note(restore(screen))
            return true
        }
        let original = isPainted(current)
            ? originals[current.lastPathComponent]
            : Wallpaper(url: current, options: workspace.desktopImageOptions(for: screen) ?? [:])
        guard let original, original.isPaintable else {
            changes.note(restore(screen))
            return false
        }
        if target.active {
            paint(screen, current: current, original: original, barHeight: bar.height,
                  cornerRadius: target.roundedCorners ? ScreenMaskView.cornerRadius : 0, changes: changes)
        } else {
            changes.note(restore(screen))
        }
        return true
    }

    private func paint(_ screen: NSScreen, current: URL, original: Wallpaper, barHeight: CGFloat,
                       cornerRadius: CGFloat, changes: PendingChanges) {
        let scale = screen.backingScaleFactor
        let size = CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale)
        let barPixels = (barHeight * scale).rounded()
        let radiusPixels = (cornerRadius * scale).rounded()
        let name = Self.fileName(for: original, size: size, barHeight: barPixels, cornerRadius: radiusPixels)
        guard current.lastPathComponent != name else { return }
        changes.expect()
        if rendering[name] != nil {
            rendering[name]?.append(changes)
            return
        }

        let target = folder.appending(path: name)
        let screenID = screen.displayID
        rendering[name] = [changes]
        Task.detached(priority: .userInitiated) { [folder] in
            let rendered = FileManager.default.fileExists(atPath: target.path)
                || Self.render(original, size: size, barHeight: barPixels,
                               cornerRadius: radiusPixels, to: target, folder: folder)
            await MainActor.run {
                let waiting = self.rendering.removeValue(forKey: name) ?? []
                guard rendered, let screen = NSScreen.screens.first(where: { $0.displayID == screenID }) else {
                    waiting.forEach { $0.finish(false) }
                    return
                }
                self.originals[name] = original
                self.setDesktopImage(target, options: [.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                                                       .allowClipping: true], for: screen)
                waiting.forEach { $0.finish(true) }
            }
        }
    }

    /// Returns whether the screen showed a painted copy.
    private func restore(_ screen: NSScreen) -> Bool {
        guard let current = workspace.desktopImageURL(for: screen), isPainted(current),
              let original = originals[current.lastPathComponent],
              FileManager.default.fileExists(atPath: original.url.path) else { return false }
        setDesktopImage(original.url, options: original.options, for: screen)
        return true
    }

    private func setDesktopImage(_ url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any], for screen: NSScreen) {
        do {
            try workspace.setDesktopImageURL(url, for: screen, options: options)
        } catch {
            Self.log.error("Setting the wallpaper failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isPainted(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path
    }

    // MARK: Originals

    private var originals: [String: Wallpaper] {
        get {
            if let cachedOriginals { return cachedOriginals }
            let loaded = defaults.data(forKey: Self.originalsKey)
                .flatMap {
                    try? NSKeyedUnarchiver.unarchivedObject(
                        ofClasses: [NSDictionary.self, NSString.self, NSNumber.self, NSColor.self, NSURL.self],
                        from: $0) as? [String: [String: Any]]
                }?
                .compactMapValues(Wallpaper.init(stored:)) ?? [:]
            cachedOriginals = loaded
            return loaded
        }
        set {
            cachedOriginals = newValue
            let stored = newValue.mapValues(\.stored) as NSDictionary
            defaults.set(try? NSKeyedArchiver.archivedData(withRootObject: stored, requiringSecureCoding: true),
                         forKey: Self.originalsKey)
        }
    }

    // MARK: Rendering

    /// Names a copy after its original and the screen it was rendered for, so a change to either renders a new one.
    nonisolated static func fileName(for original: Wallpaper, size: CGSize, barHeight: CGFloat,
                                     cornerRadius: CGFloat) -> String {
        let modified = (try? original.url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let identity = "\(original.url.path)|\(modified)|\(original.scaling.rawValue)|\(original.allowsClipping)"
        let hash = SHA256.hash(data: Data(identity.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let type = original.imageCount > 1 ? "heic" : "png"
        return "\(hash)-\(Int(size.width))x\(Int(size.height))-\(Int(barHeight))-\(Int(cornerRadius)).\(type)"
    }

    /// Where macOS draws an image of `image` size on a screen of `canvas` size.
    nonisolated static func placement(of image: CGSize, in canvas: CGSize, scaling: NSImageScaling,
                                      allowsClipping: Bool) -> CGRect {
        let fit = min(canvas.width / image.width, canvas.height / image.height)
        let fill = max(canvas.width / image.width, canvas.height / image.height)
        let factor: CGFloat
        switch scaling {
        case .scaleAxesIndependently:
            return CGRect(origin: .zero, size: canvas)
        case .scaleNone:
            factor = 1
        case .scaleProportionallyDown:
            factor = min(1, allowsClipping ? fill : fit)
        default:
            factor = allowsClipping ? fill : fit
        }
        let size = CGSize(width: image.width * factor, height: image.height * factor)
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// Paints every image of the original. Dynamic wallpapers keep their schedule, which lives in the
    /// `apple_desktop` metadata of the first image.
    nonisolated static func render(_ original: Wallpaper, size: CGSize, barHeight: CGFloat, cornerRadius: CGFloat,
                                   to target: URL,
                                           folder: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(original.url as CFURL, nil),
              let space = CGColorSpace(name: CGColorSpace.displayP3) else { return false }
        let count = CGImageSourceGetCount(source)
        let type = count > 1 ? UTType.heic : UTType.png
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return false
        }
        guard let destination = CGImageDestinationCreateWithURL(target as CFURL, type.identifier as CFString,
                                                                count, nil) else { return false }
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil),
                  let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return false }
            context.setFillColor(original.fillColor.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.interpolationQuality = .high
            context.draw(image, in: placement(of: CGSize(width: image.width, height: image.height), in: size,
                                              scaling: original.scaling, allowsClipping: original.allowsClipping))
            // The same shape as the overlay: the bar and the black outside the rounded desktop.
            let mask = CGMutablePath()
            mask.addRect(CGRect(origin: .zero, size: size))
            mask.addRoundedRect(in: CGRect(x: 0, y: 0, width: size.width, height: size.height - barHeight),
                                cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            context.addPath(mask)
            context.setFillColor(.black)
            context.fillPath(using: .evenOdd)
            guard let painted = context.makeImage() else { return false }
            let metadata = index == 0 ? dynamicMetadata(from: source) : nil
            CGImageDestinationAddImageAndMetadata(destination, painted, metadata, nil)
        }
        return CGImageDestinationFinalize(destination)
    }

    nonisolated private static func dynamicMetadata(from source: CGImageSource) -> CGImageMetadata? {
        guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] else { return nil }
        let dynamic = CGImageMetadataCreateMutable()
        for tag in tags where CGImageMetadataTagCopyPrefix(tag) as String? == "apple_desktop" {
            guard let namespace = CGImageMetadataTagCopyNamespace(tag),
                  let name = CGImageMetadataTagCopyName(tag) as String? else { continue }
            CGImageMetadataRegisterNamespaceForPrefix(dynamic, namespace, "apple_desktop" as CFString, nil)
            CGImageMetadataSetTagWithPath(dynamic, nil, "apple_desktop:\(name)" as CFString, tag)
        }
        return dynamic
    }
}

private struct SeenScreen: Equatable {
    var url: URL
    var frame: CGRect
    var target: WallpaperTarget
}

/// A desktop picture with the options macOS draws it with.
struct Wallpaper: @unchecked Sendable {
    let url: URL
    let options: [NSWorkspace.DesktopImageOptionKey: Any]

    var scaling: NSImageScaling {
        (options[.imageScaling] as? NSNumber).flatMap { NSImageScaling(rawValue: $0.uintValue) }
            ?? .scaleProportionallyUpOrDown
    }

    var allowsClipping: Bool { (options[.allowClipping] as? NSNumber)?.boolValue ?? true }
    var fillColor: NSColor { options[.fillColor] as? NSColor ?? .black }

    /// For aerials and other wallpapers that aren't image files, macOS reports the default desktop picture.
    var isPaintable: Bool {
        url.lastPathComponent != "DefaultDesktop.heic" && imageCount > 0
    }

    /// Dynamic wallpapers hold one image per appearance or time of day.
    var imageCount: Int {
        CGImageSourceCreateWithURL(url as CFURL, nil).map(CGImageSourceGetCount) ?? 0
    }

    init(url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any]) {
        self.url = url
        self.options = options
    }

    init?(stored: [String: Any]) {
        guard let url = stored["url"] as? URL else { return nil }
        var options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        for (key, value) in stored where key != "url" {
            options[NSWorkspace.DesktopImageOptionKey(rawValue: key)] = value
        }
        self.init(url: url, options: options)
    }

    var stored: [String: Any] {
        var stored: [String: Any] = ["url": url]
        for (key, value) in options { stored[key.rawValue] = value }
        return stored
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

public struct WallpaperState: Equatable, Sendable {
    /// False if a covered screen shows a wallpaper that can't be painted, like an aerial.
    public var paintable: Bool
    /// True if every wallpaper already showed what it should.
    public var settled: Bool

    public init(paintable: Bool, settled: Bool) {
        self.paintable = paintable
        self.settled = settled
    }
}

/// Collects the changes of one sync and reports when they are all on screen.
@MainActor
final class PendingChanges {
    private var pending = 1
    private var changed = false
    private let completion: @MainActor () -> Void

    init(completion: @escaping @MainActor () -> Void) {
        self.completion = completion
    }

    var isSettled: Bool { pending == 0 && !changed }

    /// Records a change made right away.
    func note(_ didChange: Bool) {
        changed = changed || didChange
    }

    /// Waits for one more change that finishes later.
    func expect() { pending += 1 }

    func finish(_ didChange: Bool) {
        note(didChange)
        pending -= 1
        guard pending == 0 else { return }
        // Always later, so the caller has the sync's result before the completion runs.
        let completion = completion
        let delay = changed ? WallpaperPainter.swapDelay : .zero
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            completion()
        }
    }

    /// Ends the sync's own synchronous part.
    func seal() { finish(false) }
}
