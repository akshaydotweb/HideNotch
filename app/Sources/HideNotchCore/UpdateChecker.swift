import Foundation
import Observation
import os

/// Looks up the latest GitHub release at launch and once a day after that.
@MainActor
@Observable
public final class UpdateChecker {
    @ObservationIgnored private static let log = Logger(subsystem: "com.niklasravnsborg.hidenotch", category: "Updates")
    nonisolated static let latestRelease = URL(string: "https://api.github.com/repos/niklasravnsborg/HideNotch/releases/latest")!
    nonisolated static let download = URL(string: "https://github.com/niklasravnsborg/HideNotch/releases/latest/download/HideNotch.dmg")!

    /// The newer version, if one is available.
    private(set) var availableVersion: String?

    @ObservationIgnored let currentVersion: String
    @ObservationIgnored private let fetchLatestTag: @Sendable () async throws -> String
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        fetchLatestTag: @escaping @Sendable () async throws -> String = UpdateChecker.fetchLatestTag
    ) {
        self.currentVersion = currentVersion
        self.fetchLatestTag = fetchLatestTag
    }

    public func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await self?.check()
                } catch {
                    Self.log.error("Update check failed: \(error.localizedDescription, privacy: .public)")
                }
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    /// Returns the newer version, if one is available.
    @discardableResult
    func check() async throws -> String? {
        let latest = String(try await fetchLatestTag().trimmingPrefix("v"))
        availableVersion = latest.compare(currentVersion, options: .numeric) == .orderedDescending ? latest : nil
        return availableVersion
    }

    private struct Release: Decodable {
        let tagName: String
    }

    public nonisolated static func fetchLatestTag() async throws -> String {
        var request = URLRequest(url: latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data).tagName
    }
}
