import Foundation
import Testing
@testable import HideNotchCore

struct L10nTests {
    @Test(arguments: L10n.supportedLanguages)
    func everyLanguageHasEveryKey(lang: String) throws {
        let lprojPath = try #require(Bundle.module.path(forResource: lang, ofType: "lproj"))
        let stringsPath = lprojPath + "/Localizable.strings"
        let dict = try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
        #expect(Set(dict.keys) == Set(L10n.keys))
        for value in dict.values {
            #expect(!value.isEmpty)
        }
    }

    @Test(arguments: L10n.supportedLanguages)
    func languageBundleReturnsTranslation(lang: String) throws {
        let lprojPath = try #require(Bundle.module.path(forResource: lang, ofType: "lproj"))
        let bundle = try #require(Bundle(path: lprojPath))
        for key in L10n.keys {
            #expect(L10n.tr(key, bundle: bundle) != key)
        }
    }

    @Test func englishStrings() throws {
        let lprojPath = try #require(Bundle.module.path(forResource: "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: lprojPath))
        #expect(L10n.tr("menu.hideNotch", bundle: bundle) == "Hide Notch")
        #expect(L10n.tr("menu.launchAtLogin", bundle: bundle) == "Launch at Login")
        #expect(L10n.tr("menu.quit", bundle: bundle) == "Quit")
    }

    @Test func infoPlistListsSupportedLanguages() throws {
        let testFilePath = URL(fileURLWithPath: #filePath)
        let repoRoot = testFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistPath = repoRoot.appendingPathComponent("Resources/Info.plist").path
        let plist = try #require(NSDictionary(contentsOfFile: plistPath))
        let languages = try #require(plist["CFBundleLocalizations"] as? [String])
        #expect(Set(languages) == Set(L10n.supportedLanguages))
        #expect(plist["CFBundleDevelopmentRegion"] as? String == "en")
    }
}
