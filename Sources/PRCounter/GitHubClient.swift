import Foundation

enum GitHubClientError: LocalizedError {
    case missingToken
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "No token from `gh auth token`; run `gh auth login`"
        case .badResponse(let detail):
            detail
        }
    }
}

actor GitHubClient {
    private var cachedToken: String?

    func fetchStats() async throws -> PRStats {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? todayStart
        let query = """
        query {
          viewer {
            login
            total: pullRequests { totalCount }
            open: pullRequests(states: OPEN) { totalCount }
            merged: pullRequests(states: MERGED) { totalCount }
            closed: pullRequests(states: CLOSED) { totalCount }
          }
          today: search(query: "author:@me type:pr created:>=\(Self.isoTimestamp(todayStart))", type: ISSUE) { issueCount }
          month: search(query: "author:@me type:pr created:>=\(Self.isoTimestamp(monthStart))", type: ISSUE) { issueCount }
        }
        """
        let responseData = try await postGraphQL(query: query)
        let decoded = try JSONDecoder().decode(StatsResponse.self, from: responseData)
        if let firstError = decoded.errors?.first {
            throw GitHubClientError.badResponse(firstError.message)
        }
        guard let payload = decoded.data else {
            throw GitHubClientError.badResponse("Empty GraphQL response")
        }
        return PRStats(
            login: payload.viewer.login,
            total: payload.viewer.total.totalCount,
            open: payload.viewer.open.totalCount,
            merged: payload.viewer.merged.totalCount,
            closed: payload.viewer.closed.totalCount,
            today: payload.today.issueCount,
            thisMonth: payload.month.issueCount
        )
    }

    private func postGraphQL(query: String) async throws -> Data {
        let token = try resolveToken()
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["query": query])
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubClientError.badResponse("No HTTP response")
        }
        if httpResponse.statusCode == 401 {
            cachedToken = nil
        }
        guard httpResponse.statusCode == 200 else {
            throw GitHubClientError.badResponse("HTTP \(httpResponse.statusCode)")
        }
        return responseData
    }

    private func resolveToken() throws -> String {
        if let cachedToken { return cachedToken }
        if let envToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !envToken.isEmpty {
            cachedToken = envToken
            return envToken
        }
        let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = ghCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw GitHubClientError.missingToken
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let tokenData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let ghToken = String(decoding: tokenData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !ghToken.isEmpty else {
            throw GitHubClientError.missingToken
        }
        cachedToken = ghToken
        return ghToken
    }

    private static func isoTimestamp(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .colon))
    }
}

private struct StatsResponse: Decodable {
    struct Count: Decodable { let totalCount: Int }
    struct SearchCount: Decodable { let issueCount: Int }
    struct Viewer: Decodable {
        let login: String
        let total: Count
        let open: Count
        let merged: Count
        let closed: Count
    }
    struct Payload: Decodable {
        let viewer: Viewer
        let today: SearchCount
        let month: SearchCount
    }
    struct GraphQLError: Decodable { let message: String }

    let data: Payload?
    let errors: [GraphQLError]?
}
