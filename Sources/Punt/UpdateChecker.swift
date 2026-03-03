import Foundation

enum UpdateChecker {
    struct Release {
        let version: String
        let downloadURL: URL
    }

    enum CheckError: Error {
        case networkError(Error)
        case invalidResponse
        case noAssetFound
        case parseError
    }

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/mpalczew/punt/releases/latest"
    )!

    static func fetchLatestRelease(
        completion: @escaping (Result<Release, CheckError>) -> Void
    ) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                completion(.failure(.parseError))
                return
            }

            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard let asset = assets.first(where: {
                      ($0["name"] as? String)?.hasSuffix("-universal.zip") == true
                  }),
                  let urlString = asset["browser_download_url"] as? String,
                  let downloadURL = URL(string: urlString) else {
                completion(.failure(.noAssetFound))
                return
            }

            completion(.success(Release(version: version, downloadURL: downloadURL)))
        }.resume()
    }

    static func isNewer(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
