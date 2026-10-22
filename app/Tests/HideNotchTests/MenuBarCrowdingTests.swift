import CoreGraphics
import Testing
@testable import HideNotchCore

struct MenuBarCrowdingTests {
    let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)

    func windows(_ count: Int, top: CGFloat, x: CGFloat = 100) -> [CGRect] {
        Array(repeating: CGRect(x: x, y: top, width: 800, height: 600), count: count)
    }

    @Test func crowdedOnceEnoughWindowsReachTheTop() {
        #expect(!MenuBarCrowding.isCrowded(windows: windows(9, top: 38), screens: [screen]))
        #expect(MenuBarCrowding.isCrowded(windows: windows(10, top: 38), screens: [screen]))
    }

    @Test func ignoresLowerWindowsAndOtherScreens() {
        let lower = windows(5, top: 38) + windows(5, top: 200)
        #expect(!MenuBarCrowding.isCrowded(windows: lower, screens: [screen]))
        #expect(!MenuBarCrowding.isCrowded(windows: windows(10, top: 38, x: 2000), screens: [screen]))
    }
}
