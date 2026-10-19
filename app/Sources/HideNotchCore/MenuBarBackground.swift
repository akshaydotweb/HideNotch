import Darwin
import os

/// Uses the same private SkyLight API as System Settings on macOS Tahoe.
@MainActor
enum MenuBarBackground {
    private static let log = Logger(subsystem: "com.leether.HideNotch", category: "MenuBarBackground")
    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let setBlurredAppearance: (@convention(c) (Bool, Bool) -> Void)? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSSetMenuBarUseBlurredAppearance") else {
            return nil
        }
        return unsafeBitCast(symbol, to: (@convention(c) (Bool, Bool) -> Void).self)
    }()

    private static let getBlurredAppearance: (@convention(c) () -> Bool)? = {
        guard let skyLight, let symbol = dlsym(skyLight, "SLSGetMenuBarUseBlurredAppearance") else {
            return nil
        }
        return unsafeBitCast(symbol, to: (@convention(c) () -> Bool).self)
    }()

    static var isEnabled: Bool? { getBlurredAppearance?() }

    static func disable() {
        guard let setBlurredAppearance else {
            log.error("System menu bar background API is unavailable")
            return
        }
        // The second argument persists the change, matching System Settings.
        setBlurredAppearance(false, true)
    }
}
