import Foundation

enum AIEndpointBuilder {
    static func endpoint(
        baseURL: String,
        path: String,
        localNetworkEnabled: Bool
    ) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              scheme == "https" || scheme == "http" else {
            throw RecognitionError.invalidURL
        }

        if scheme == "http" {
            guard localNetworkEnabled, isPrivateHost(host) else {
                throw RecognitionError.localNetworkDisabled
            }
        }

        var normalizedPath = components.path
        while normalizedPath.hasSuffix("/") { normalizedPath.removeLast() }
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath + suffix
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw RecognitionError.invalidURL }
        return url
    }

    static func isPrivateHost(_ host: String) -> Bool {
        let value = host.lowercased()
        if value == "localhost" || value.hasSuffix(".local") { return true }
        if value == "::1" { return true }

        let parts = value.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ 0...255 ~= $0 }) else { return false }
        if parts[0] == 10 || parts[0] == 127 { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 100 && (64...127).contains(parts[1]) { return true }
        return false
    }
}
