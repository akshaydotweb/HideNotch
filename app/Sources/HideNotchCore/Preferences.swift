import Foundation

public final class Preferences {
    static let overlayEnabledKey = "overlayEnabled"
    static let showMenuBarIconKey = "showMenuBarIcon"
    static let roundedCornersEnabledKey = "roundedCornersEnabled"
    static let screensWithoutNotchEnabledKey = "screensWithoutNotchEnabled"
    static let didSetUpLoginItemKey = "didSetUpLoginItem"
    static let hidesWallpaperWarningKey = "hidesWallpaperWarning"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.overlayEnabledKey: true,
            Self.showMenuBarIconKey: true,
            Self.roundedCornersEnabledKey: true,
        ])
    }

    public var overlayEnabled: Bool {
        get { defaults.bool(forKey: Self.overlayEnabledKey) }
        set { defaults.set(newValue, forKey: Self.overlayEnabledKey) }
    }

    public var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Self.showMenuBarIconKey) }
        set { defaults.set(newValue, forKey: Self.showMenuBarIconKey) }
    }

    public var roundedCornersEnabled: Bool {
        get { defaults.bool(forKey: Self.roundedCornersEnabledKey) }
        set { defaults.set(newValue, forKey: Self.roundedCornersEnabledKey) }
    }

    public var screensWithoutNotchEnabled: Bool {
        get { defaults.bool(forKey: Self.screensWithoutNotchEnabledKey) }
        set { defaults.set(newValue, forKey: Self.screensWithoutNotchEnabledKey) }
    }

    public var hidesWallpaperWarning: Bool {
        get { defaults.bool(forKey: Self.hidesWallpaperWarningKey) }
        set { defaults.set(newValue, forKey: Self.hidesWallpaperWarningKey) }
    }

    public var didSetUpLoginItem: Bool {
        get { defaults.bool(forKey: Self.didSetUpLoginItemKey) }
        set { defaults.set(newValue, forKey: Self.didSetUpLoginItemKey) }
    }
}
