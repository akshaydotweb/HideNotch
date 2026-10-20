# HideNotch

A macOS menu-bar utility that paints the menu bar area on notched screens pure black, so the notch blends in with the menu bar. It also adds black corners with a 16-point radius around the desktop, with the upper corners directly below the menu bar. When the overlay appears, the menu-bar strip and upper corners slide down together from the top while the bottom corners grow into place. Animations take 0.6 seconds.

## Requirements

- macOS 26 or later
- A MacBook with a notched built-in display (other displays are unaffected unless you include them)

## Installation

1. Download `HideNotch.dmg` from the [latest release](https://github.com/niklasravnsborg/HideNotch/releases/latest) and open it.
2. Drag `HideNotch.app` onto the `Applications` icon in the window to install it.
3. First launch: double-click `HideNotch.app` from `~/Applications` or the Applications folder. The app has no Dock icon; once running it only shows an icon in the menu bar.

## Usage

Click the menu-bar icon to open a panel. The switch at the top turns HideNotch on and off. The checkboxes below hold the options, and the "…" menu has launch at login, the icon setting, and Quit.

- **Hide Notch** (the switch): toggles the black bar overlay. Changes apply immediately without a confirmation prompt. Enabling it also turns off “Show menu bar background” in System Settings so the system background does not cover the overlay. If you turn the system background back on, HideNotch switches off automatically within a second, removes its overlay without animation, restores the menu-bar icon, and explains which setting is required. HideNotch leaves that setting unchanged when disabled or closed. This uses an undocumented macOS API.
- **Rounded screen corners**: toggles the 16-point black corner masks below the menu bar and at the bottom of the screen, animating the radius over 0.6 seconds. Enabled by default; the setting persists across restarts. The corners appear when Hide Notch is active.
- **Include displays without notch**: also paints the menu bar and corners black on displays without a notch, such as external monitors. Off by default; the setting persists across restarts. Displays without a visible menu bar (auto-hidden, or secondary displays when “Displays have separate Spaces” is off) stay uncovered.
- **Launch at Login** ("…" menu): when checked, the app starts automatically at login. If the system requires approval in System Settings, the item reads "Launch at Login (Approve in System Settings)"; clicking it again opens the corresponding System Settings page.
- **Show Menu Bar Icon** ("…" menu): uncheck to hide the icon while keeping the overlay active. A dialog explains how to restore it; Cancel brings it back immediately. Open HideNotch again from Applications, Spotlight, or `open ~/Applications/HideNotch.app` to restore the icon and access the panel. The setting persists across restarts and launch at login. If macOS doesn’t show the icon, for example because HideNotch is turned off under “Allow in the Menu Bar”, launching or reopening HideNotch shows a dialog with a button to open Menu Bar settings.
- **Quit** ("…" menu): plays the reverse reveal animation, then quits the app.

## Languages

The interface is localized into 11 languages: English (default/fallback), Japanese, Korean, French, German, Spanish, Italian, Portuguese, Thai, Vietnamese, and Indonesian. Translations are machine-assisted; corrections are welcome via issues/PRs.

## Known Limitations

- **Lock screen / wake-from-sleep unlock screen**: not handled, the notch is briefly visible — the lock screen does not composite application windows from the current user session.
- **First login screen after reboot (with FileVault enabled)**: not handled, that screen runs in the pre-unlock boot environment where third-party code cannot run.
- **Logout / switch-user login window**: not implemented in v1 (would require installing a pre-login agent that needs administrator privileges).

## Building from Source

```bash
cd app
swift test              # run the unit tests
scripts/build-app.sh    # ad-hoc signed build, installed to ~/Applications for local debugging
scripts/build-dmg.sh    # produce a signed + notarized distributable DMG (dist/HideNotch.dmg)
```

`app/scripts/build-dmg.sh` reads these optional environment variables:

- `HIDENOTCH_SIGN_IDENTITY`: the signing identity, defaults to `Developer ID Application`, which matches the Developer ID certificate in your keychain.
- `HIDENOTCH_NOTARY_PROFILE`: the keychain profile used by `xcrun notarytool`, defaults to `HideNotch`.
- `HIDENOTCH_NOTARY_KEY`, `HIDENOTCH_NOTARY_KEY_ID`, `HIDENOTCH_NOTARY_ISSUER`: an App Store Connect API key (`.p8` path, key ID, issuer ID). When set, they replace the keychain profile. CI uses these.

To notarize locally, store your credentials in a keychain profile once:

```bash
xcrun notarytool store-credentials HideNotch \
  --apple-id <your-apple-id> \
  --team-id <your-team-id> \
  --password <app-specific-password>
```

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `app/Resources/Info.plist` and commit.
2. Tag and push: `git tag v0.1.0 && git push origin v0.1.0`.

`.github/workflows/release.yml` checks that the tag matches the app version, runs the tests, builds, signs, and notarizes `HideNotch.dmg`, and publishes it as a GitHub release. It needs these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_P12`: the Developer ID Application certificate with its private key, exported as `.p12` and base64 encoded.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: the password of that `.p12`.
- `NOTARY_KEY_P8`: the contents of the App Store Connect API key file.
- `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`: the key ID and issuer ID shown next to that key in App Store Connect.

## Contributing

The repo has two parts: the macOS app in `app/` and the website in `website/`.

Start each commit message with the scope it touches: `app:`, `website:`, or `root:` for repo-level files like this README. Keep a commit within one scope where possible.

```
app: replace status item menu with a settings popover
```
