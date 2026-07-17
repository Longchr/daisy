import Foundation

enum MerchantNormalizer {
    static func normalize(_ merchant: String) -> String {
        merchant
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: #"[\s\p{P}\p{S}]+"#, with: "", options: .regularExpression)
            .lowercased()
    }
}
