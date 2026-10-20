import Observation
import Sparkle

/// Keeps HideNotch up to date with Sparkle. Updates download in the background and install when
/// HideNotch quits, or right away from the panel's Update button.
@MainActor
@Observable
public final class Updater: NSObject, SPUUpdaterDelegate {
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var installNow: (() -> Void)?

    /// Whether an update is downloaded and waiting to be installed.
    private(set) var isUpdateReady = false

    public override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }

    public func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func installUpdate() {
        installNow?()
    }

    public func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                        immediateInstallationBlock: @escaping () -> Void) -> Bool {
        installNow = immediateInstallationBlock
        isUpdateReady = true
        return true
    }
}
