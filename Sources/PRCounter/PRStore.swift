import Foundation
import Observation

struct PRStats: Sendable {
    let login: String
    let total: Int
    let open: Int
    let merged: Int
    let closed: Int
    let today: Int
    let thisMonth: Int
}

@MainActor
@Observable
final class PRStore {
    private(set) var stats: PRStats?
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    private let refreshInterval: Duration = .seconds(60)
    private let client = GitHubClient()

    init() {
        Task { await pollForever() }
    }

    var menuBarTitle: String {
        guard let stats else { return errorMessage == nil ? "…" : "!" }
        return "\(stats.total)"
    }

    func refresh() async {
        do {
            stats = try await client.fetchStats()
            errorMessage = nil
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollForever() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: refreshInterval)
        }
    }
}
