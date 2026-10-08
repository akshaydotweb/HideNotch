import Foundation

public final class Preferences {
    static let overlayEnabledKey = "overlayEnabled"
    static let showMenuBarIconKey = "showMenuBarIcon"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.overlayEnabledKey: true, Self.showMenuBarIconKey: true])
    }

    public var overlayEnabled: Bool {
        get { defaults.bool(forKey: Self.overlayEnabledKey) }
        set { defaults.set(newValue, forKey: Self.overlayEnabledKey) }
    }

    public var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Self.showMenuBarIconKey) }
        set { defaults.set(newValue, forKey: Self.showMenuBarIconKey) }
    }
}
