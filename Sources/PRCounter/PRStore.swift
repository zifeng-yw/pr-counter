import Foundation
import Observation

enum ChartGranularity: String, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case all = "All"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month, .all: .month
        }
    }

    var fixedBucketCount: Int? {
        switch self {
        case .day: 30
        case .week: 26
        case .month: 12
        case .all: nil
        }
    }
}

struct ChartBucket: Identifiable, Sendable {
    let start: Date
    let count: Int
    var id: Date { start }
}

struct PRStats: Sendable {
    let profile: GitHubProfile
    let pullRequests: [PullRequestSummary]

    var total: Int { pullRequests.count }
    var open: Int { pullRequests.count { $0.state == .open } }
    var merged: Int { pullRequests.count { $0.state == .merged } }
    var closed: Int { pullRequests.count { $0.state == .closed } }

    var mergeRate: Double? {
        let decided = merged + closed
        return decided == 0 ? nil : Double(merged) / Double(decided)
    }

    func scoped(to buckets: [ChartBucket]) -> PRStats {
        guard let rangeStart = buckets.first?.start else { return self }
        return PRStats(profile: profile, pullRequests: pullRequests.filter { $0.createdAt >= rangeStart })
    }

    func buckets(for granularity: ChartGranularity, calendar: Calendar = .current, now: Date = Date()) -> [ChartBucket] {
        let component = granularity.calendarComponent
        guard let currentStart = calendar.dateInterval(of: component, for: now)?.start else { return [] }
        let bucketCount = granularity.fixedBucketCount ?? bucketCountSinceFirstPullRequest(component: component, currentStart: currentStart, calendar: calendar)
        let bucketStarts = (0..<bucketCount).reversed().compactMap {
            calendar.date(byAdding: component, value: -$0, to: currentStart)
        }
        var countsByStart: [Date: Int] = [:]
        for pullRequest in pullRequests {
            if let bucketStart = calendar.dateInterval(of: component, for: pullRequest.createdAt)?.start {
                countsByStart[bucketStart, default: 0] += 1
            }
        }
        return bucketStarts.map { ChartBucket(start: $0, count: countsByStart[$0] ?? 0) }
    }

    private func bucketCountSinceFirstPullRequest(component: Calendar.Component, currentStart: Date, calendar: Calendar) -> Int {
        guard let firstCreatedAt = pullRequests.map(\.createdAt).min(),
              let firstStart = calendar.dateInterval(of: component, for: firstCreatedAt)?.start else { return 1 }
        let elapsed = calendar.dateComponents([component], from: firstStart, to: currentStart).value(for: component) ?? 0
        return elapsed + 1
    }
}

@MainActor
@Observable
final class PRStore {
    private(set) var stats: PRStats?
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    let refreshInterval: Duration = .seconds(60)
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
            let history = try await client.fetchHistory()
            stats = PRStats(profile: history.profile, pullRequests: history.pullRequests)
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
