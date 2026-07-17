import Foundation

enum AccountResolver {
    static func resolveID(
        accounts: [Account],
        paymentChannel: String?,
        paymentMethodHint: String?
    ) -> UUID? {
        let clues = [paymentChannel, paymentMethodHint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if let namedMatch = accounts.first(where: {
            !$0.isArchived && clues.localizedCaseInsensitiveContains($0.name)
        }) {
            return namedMatch.id
        }

        let preferredName: String?
        if clues.contains("alipay") || clues.contains("支付宝") {
            preferredName = "支付宝"
        } else if clues.contains("wechat") || clues.contains("weixin") || clues.contains("微信") {
            preferredName = "微信支付"
        } else if clues.contains("bank") || clues.contains("card") || clues.contains("银行卡") {
            preferredName = "银行卡"
        } else if clues.contains("cash") || clues.contains("现金") {
            preferredName = "现金"
        } else {
            preferredName = nil
        }

        return preferredName.flatMap { name in
            accounts.first { !$0.isArchived && $0.name == name }?.id
        }
    }
}
