import Foundation

enum ModelOutputParser {
    static func jsonData(from content: String) throws -> Data {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: .newlines)
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
            if cleaned.lowercased().hasPrefix("json") {
                cleaned.removeFirst(4)
            }
        }

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              start <= end else {
            throw RecognitionError.invalidResponse
        }
        let json = String(cleaned[start...end])
        guard let data = json.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw RecognitionError.invalidResponse
        }
        return data
    }
}
