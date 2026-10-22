import AppKit

/// macOS Tahoe paints the wallpaper over the black bar once enough windows reach the menu bar.
enum MenuBarCrowding {
    static let windowLimit = 10
    /// Windows whose top edge lies this close to the top of the screen count.
    static let reach: CGFloat = 60

    /// Frames use window server coordinates: origin at the top left of the main screen, y pointing down.
    static func isCrowded(windows: [CGRect], screens: [CGRect]) -> Bool {
        screens.contains { screen in
            let band = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: reach)
            return windows.count { band.contains(CGPoint(x: $0.midX, y: $0.minY)) }
                >= windowLimit
        }
    }

    @MainActor static func isCrowded(screens: [CGRect]) -> Bool {
        crowded(screens).contains(true)
    }

    /// Checks each of the given screens, in AppKit coordinates, against one read of the windows on screen.
    @MainActor static func crowded(_ screens: [CGRect]) -> [Bool] {
        guard !screens.isEmpty else { return [] }
        guard let mainHeight = NSScreen.screens.first?.frame.height,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else {
            return screens.map { _ in false }
        }
        let windows = info.compactMap { window -> CGRect? in
            guard window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
        return screens.map {
            let flipped = CGRect(x: $0.minX, y: mainHeight - $0.maxY, width: $0.width, height: $0.height)
            return isCrowded(windows: windows, screens: [flipped])
        }
    }
}
