# HideNotch

HideNotch paints the menu bar black on MacBooks with a notch, so the notch blends into the menu bar. It can also round the corners of your screen.

## Requirements

macOS 26 or later.

## Installation

1. Download `HideNotch.dmg` from the [latest release](https://github.com/niklasravnsborg/HideNotch/releases/latest).
2. Open it and drag HideNotch into Applications.
3. Open HideNotch. It runs in the menu bar and has no Dock icon.

HideNotch updates itself in the background.

## Usage

Click the menu bar icon to open the panel:

- The switch turns HideNotch on and off. Turning it on also turns off "Show menu bar background" in System Settings, which would otherwise cover the black bar.
- **Rounded screen corners** adds black rounded corners to the screen.
- **Include displays without notch** also paints the menu bar black on external displays.

The "…" menu has launch at login, update checks, and an option to hide the menu bar icon. If you hide it, open HideNotch again from Applications or Spotlight to get it back.

## Known limitations

- The notch stays visible on the lock screen and the login window, because macOS doesn't show app windows there.
- Screen Time's Downtime and App Limits hide HideNotch along with other limited apps. To keep it running, add HideNotch to the apps that are always allowed.

## License

See [LICENSE](LICENSE).
