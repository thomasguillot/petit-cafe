import Foundation
import PetitCafeKit

struct ReleaseFetcher: Sendable {
    enum FetchError: LocalizedError {
        case insecureURL, badStatus(Int), tooLarge

        var errorDescription: String? {
            switch self {
            case .insecureURL: "The update address isn't secure."
            case .badStatus(403), .badStatus(429): "GitHub is limiting requests from this network. Try again later."
            case let .badStatus(code): "GitHub answered with an error (\(code))."
            case .tooLarge: "GitHub's answer was larger than expected."
            }
        }
    }

    private static let repoSlug = "thomasguillot/petit-cafe"
    // A page of history, not just /latest: the update window shows the notes for
    // every release the user skipped, so it needs more than the newest one.
    private static let pageSize = 30
    private static let maxBytes = 2 * 1024 * 1024

    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func fetchReleases() async throws -> [GitHubRelease] {
        let endpoint = "https://api.github.com/repos/\(Self.repoSlug)/releases?per_page=\(Self.pageSize)"
        guard let url = URL(string: endpoint), url.scheme?.lowercased() == "https" else {
            throw FetchError.insecureURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else { throw FetchError.badStatus(-1) }
        guard http.statusCode == 200 else { throw FetchError.badStatus(http.statusCode) }
        guard http.expectedContentLength <= Int64(Self.maxBytes) else { throw FetchError.tooLarge }

        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            guard data.count <= Self.maxBytes else { throw FetchError.tooLarge }
        }

        return try JSONDecoder().decode([GitHubRelease].self, from: data)
    }
}
