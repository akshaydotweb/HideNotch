import Foundation

/// User-facing strings, localized via Resources/<lang>.lproj/Localizable.strings.
public enum L10n {
    static let supportedLanguages = ["en", "ja", "ko", "fr", "de", "es", "it", "pt", "th", "vi", "id"]
    static let keys = [
        "menu.hideNotch", "menu.roundedScreenCorners", "menu.displaysWithoutNotch", "menu.launchAtLogin", "menu.launchAtLogin.failed",
        "menu.launchAtLogin.needsApproval", "menu.showMenuBarIcon", "menu.quit", "panel.description",
        "panel.update", "hint.hideNotch", "menu.checkForUpdates",
        "alert.update.title", "alert.update.message", "alert.update.download", "alert.update.later",
        "alert.upToDate.title", "alert.upToDate.message", "alert.updateFailed.title",
        "alert.systemBackground.title", "alert.systemBackground.message",
        "alert.hiddenIcon.title", "alert.hiddenIcon.message", "alert.hiddenIcon.confirm", "alert.hiddenIcon.cancel",
        "alert.disallowedIcon.title", "alert.disallowedIcon.message", "alert.disallowedIcon.openSettings",
    ]

    static var hideNotch: String { tr("menu.hideNotch") }
    static var roundedScreenCorners: String { tr("menu.roundedScreenCorners") }
    static var displaysWithoutNotch: String { tr("menu.displaysWithoutNotch") }
    static var launchAtLogin: String { tr("menu.launchAtLogin") }
    static var launchAtLoginFailed: String { tr("menu.launchAtLogin.failed") }
    static var launchAtLoginNeedsApproval: String { tr("menu.launchAtLogin.needsApproval") }
    static var quit: String { tr("menu.quit") }
    static var showMenuBarIcon: String { tr("menu.showMenuBarIcon") }
    static var description: String { tr("panel.description") }
    static var update: String { tr("panel.update") }
    static var hint: String { tr("hint.hideNotch") }
    static var checkForUpdates: String { tr("menu.checkForUpdates") }
    static func updateAlertTitle(_ version: String) -> String { String(format: tr("alert.update.title"), version) }
    static func updateAlertMessage(_ version: String) -> String { String(format: tr("alert.update.message"), version) }
    static var updateAlertDownload: String { tr("alert.update.download") }
    static var updateAlertLater: String { tr("alert.update.later") }
    static var upToDateAlertTitle: String { tr("alert.upToDate.title") }
    static func upToDateAlertMessage(_ version: String) -> String { String(format: tr("alert.upToDate.message"), version) }
    static var updateFailedAlertTitle: String { tr("alert.updateFailed.title") }
    static var systemBackgroundAlertTitle: String { tr("alert.systemBackground.title") }
    static var systemBackgroundAlertMessage: String { tr("alert.systemBackground.message") }
    static var hiddenIconAlertTitle: String { tr("alert.hiddenIcon.title") }
    static var hiddenIconAlertMessage: String { tr("alert.hiddenIcon.message") }
    static var hiddenIconAlertConfirm: String { tr("alert.hiddenIcon.confirm") }
    static var hiddenIconAlertCancel: String { tr("alert.hiddenIcon.cancel") }

    static var disallowedIconAlertTitle: String { tr("alert.disallowedIcon.title") }
    static var disallowedIconAlertMessage: String { tr("alert.disallowedIcon.message") }
    static var disallowedIconAlertOpenSettings: String { tr("alert.disallowedIcon.openSettings") }

    /// SwiftPM's Bundle.module only looks next to the .app and in the build directory,
    /// so the packaged app has to find the resource bundle in Contents/Resources itself.
    static let resources = Bundle.main.url(forResource: "HideNotch_HideNotchCore", withExtension: "bundle")
        .flatMap(Bundle.init(url:)) ?? .module

    static func tr(_ key: String, bundle: Bundle = resources) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
