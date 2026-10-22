import AppKit
import SwiftUI

/// The status item's popover: the main toggle, then the options.
struct SettingsView: View {
    let controller: StatusItemController

    var body: some View {
        VStack(spacing: 12) {
            header
            hero
            options
            // Only while the bar is gone: macOS shows an animated wallpaper over it.
            if controller.isOverlayEnabled && !controller.isWallpaperPaintable && controller.isMenuBarCrowded {
                note(L10n.animatedWallpaper)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "HideNotch")
                .font(.title2.weight(.semibold))
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text(verbatim: "v\(version)")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            if controller.updates.isUpdateReady {
                Button(L10n.update, action: controller.updates.installUpdate)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            Spacer()
            Menu {
                Toggle(controller.launchAtLoginTitle,
                       isOn: binding(controller.isLaunchAtLoginEnabled, controller.toggleLoginItem))
                Toggle(L10n.showMenuBarIcon, isOn: binding(controller.isMenuBarIconShown, controller.toggleMenuBarIcon))
                Button(L10n.checkForUpdates, action: controller.checkForUpdates)
                Divider()
                Button(L10n.quit, action: controller.quit)
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .foregroundStyle(.secondary)
            .fixedSize()
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Toggle(L10n.hideNotch, isOn: binding(controller.isOverlayEnabled, controller.toggleOverlay))
                .toggleStyle(.switch)
                .labelsHidden()
            Text(L10n.description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .card()
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L10n.roundedScreenCorners,
                   isOn: binding(controller.isRoundedCornersEnabled, controller.toggleRoundedCorners))
            Toggle(L10n.displaysWithoutNotch,
                   isOn: binding(controller.isScreensWithoutNotchEnabled, controller.toggleScreensWithoutNotch))
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    /// The controller owns the state; a toggle only asks it to flip.
    private func binding(_ value: Bool, _ toggle: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: { _ in toggle() })
    }
}

/// Shown on its own the first time an animated wallpaper replaces the black bar.
struct WarningView: View {
    let dismiss: () -> Void
    let dismissForever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.animatedWallpaper, systemImage: "exclamationmark.triangle")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L10n.dontShowAgain, action: dismissForever)
                Button(L10n.hiddenIconAlertConfirm, action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

/// The launch hint: clicking it opens the panel, like clicking the icon.
struct HintView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L10n.hint)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

private extension View {
    func card() -> some View {
        background(.quaternary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
