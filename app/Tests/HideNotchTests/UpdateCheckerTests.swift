import Testing
@testable import HideNotchCore

@MainActor
struct UpdateCheckerTests {
    @Test(arguments: [
        ("v0.2.0", "0.1.0", "0.2.0"),
        ("v0.10.0", "0.9.0", "0.10.0"),
        ("v0.1.0", "0.1.0", nil),
        ("v0.1.0", "0.2.0", nil),
    ])
    func comparesVersionsNumerically(tag: String, current: String, expected: String?) async throws {
        let sut = UpdateChecker(currentVersion: current, fetchLatestTag: { tag })
        try await sut.check()
        #expect(sut.availableVersion == expected)
    }
}
