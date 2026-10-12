import Foundation

/// User-facing strings, localized via Resources/<lang>.lproj/Localizable.strings.
public enum L10n {
    static let supportedLanguages = ["en", "ja", "ko", "fr", "de", "es", "it", "pt", "th", "vi", "id"]
    static let keys = [
        "menu.hideNotch", "menu.roundedScreenCorners", "menu.displaysWithoutNotch", "menu.launchAtLogin", "menu.launchAtLogin.failed",
        "menu.launchAtLogin.needsApproval", "menu.showMenuBarIcon", "menu.quit",
        "alert.systemBackground.title", "alert.systemBackground.message",
        "alert.hiddenIcon.title", "alert.hiddenIcon.message", "alert.hiddenIcon.confirm", "alert.hiddenIcon.cancel",
    ]

    static var hideNotch: String { tr("menu.hideNotch") }
    static var roundedScreenCorners: String { tr("menu.roundedScreenCorners") }
    static var displaysWithoutNotch: String { tr("menu.displaysWithoutNotch") }
    static var launchAtLogin: String { tr("menu.launchAtLogin") }
    static var launchAtLoginFailed: String { tr("menu.launchAtLogin.failed") }
    static var launchAtLoginNeedsApproval: String { tr("menu.launchAtLogin.needsApproval") }
    static var quit: String { tr("menu.quit") }
    static var showMenuBarIcon: String { tr("menu.showMenuBarIcon") }
    static var systemBackgroundAlertTitle: String { tr("alert.systemBackground.title") }
    static var systemBackgroundAlertMessage: String { tr("alert.systemBackground.message") }
    static var hiddenIconAlertTitle: String { tr("alert.hiddenIcon.title") }
    static var hiddenIconAlertMessage: String { tr("alert.hiddenIcon.message") }
    static var hiddenIconAlertConfirm: String { tr("alert.hiddenIcon.confirm") }
    static var hiddenIconAlertCancel: String { tr("alert.hiddenIcon.cancel") }

    static func tr(_ key: String, bundle: Bundle = .module) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
