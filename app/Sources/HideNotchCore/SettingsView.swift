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
            Spacer()
            Menu {
                Toggle(controller.launchAtLoginTitle,
                       isOn: binding(controller.isLaunchAtLoginEnabled, controller.toggleLoginItem))
                Toggle(L10n.showMenuBarIcon, isOn: binding(controller.isMenuBarIconShown, controller.toggleMenuBarIcon))
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

    /// The controller owns the state; a toggle only asks it to flip.
    private func binding(_ value: Bool, _ toggle: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: { _ in toggle() })
    }
}

private extension View {
    func card() -> some View {
        background(.quaternary.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
