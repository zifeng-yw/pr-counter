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

enum PullRequestState: String, Decodable, Sendable {
    case open = "OPEN"
    case merged = "MERGED"
    case closed = "CLOSED"
}

struct PullRequestSummary: Decodable, Sendable {
    let createdAt: Date
    let state: PullRequestState
}

struct PullRequestHistory: Sendable {
    let login: String
    let pullRequests: [PullRequestSummary]
}

actor GitHubClient {
    private var cachedToken: String?
    private let pageQuery = """
    query($cursor: String) {
      viewer {
        login
        pullRequests(first: 100, after: $cursor, orderBy: {field: CREATED_AT, direction: DESC}) {
          pageInfo { hasNextPage endCursor }
          nodes { createdAt state }
        }
      }
    }
    """

    func fetchHistory() async throws -> PullRequestHistory {
        var collectedPullRequests: [PullRequestSummary] = []
        var cursor: String?
        var login = ""
        repeat {
            let page = try await fetchPage(after: cursor)
            login = page.viewer.login
            collectedPullRequests.append(contentsOf: page.viewer.pullRequests.nodes)
            cursor = page.viewer.pullRequests.pageInfo.hasNextPage ? page.viewer.pullRequests.pageInfo.endCursor : nil
        } while cursor != nil
        return PullRequestHistory(login: login, pullRequests: collectedPullRequests)
    }

    private func fetchPage(after cursor: String?) async throws -> PageResponse.Payload {
        let token = try resolveToken()
        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GraphQLRequest(query: pageQuery, variables: ["cursor": cursor]))
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PageResponse.self, from: responseData)
        if let firstError = decoded.errors?.first {
            throw GitHubClientError.badResponse(firstError.message)
        }
        guard let payload = decoded.data else {
            throw GitHubClientError.badResponse("Empty GraphQL response")
        }
        return payload
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
}

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: String?]
}

private struct PageResponse: Decodable {
    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let endCursor: String?
    }
    struct Connection: Decodable {
        let pageInfo: PageInfo
        let nodes: [PullRequestSummary]
    }
    struct Viewer: Decodable {
        let login: String
        let pullRequests: Connection
    }
    struct Payload: Decodable {
        let viewer: Viewer
    }
    struct GraphQLError: Decodable { let message: String }

    let data: Payload?
    let errors: [GraphQLError]?
}
