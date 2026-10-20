# Agent notes

- `app/` is the Swift package for the macOS app. Run `swift test` from there.
- `website/` is the landing page. Use bun there.

## Building

From `app/`:

- `scripts/build-app.sh` builds an ad-hoc signed app into `~/Applications` for local testing.
- `scripts/build-dmg.sh` builds a signed and notarized `dist/HideNotch.dmg`. Locally it notarizes with a keychain profile, created once with `xcrun notarytool store-credentials HideNotch --apple-id <id> --team-id <team> --password <app-specific-password>`.

## Releasing

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `app/Resources/Info.plist` and commit.
2. Tag and push, e.g. `git tag v0.3.1 && git push origin v0.3.1`.

`.github/workflows/release.yml` builds, notarizes, and publishes the DMG and `appcast.xml`. Its secrets:

- `DEVELOPER_ID_CERTIFICATE_P12`, `DEVELOPER_ID_CERTIFICATE_PASSWORD`: the Developer ID Application certificate with its private key, as a base64 encoded `.p12`, and its password.
- `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`: an App Store Connect API key file's contents, its key ID, and the issuer ID.
- `SPARKLE_PRIVATE_KEY`: the EdDSA update signing key, exported with `generate_keys -x` from `app/.build/artifacts/sparkle/Sparkle/bin`. Its public half is `SUPublicEDKey` in `Info.plist`. Losing it means installed apps reject all future updates, so keep a backup.

## Commits

Start each commit message with the scope it touches: `app:`, `website:`, or `root:` for repo-level files. Keep a commit within one scope where possible.

```
app: replace status item menu with a settings popover
```
