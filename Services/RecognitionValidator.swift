import Foundation

enum RecognitionValidator {
    static func validate(
        _ payload: RecognitionPayload,
        ocrText: String,
        allowedCategoryIDs: Set<String>,
        categoryKinds: [String: TransactionKind] = [:],
        autoSaveThreshold: Double,
        highValueThresholdMinor: Int64,
        now: Date = Date()
    ) throws -> ValidatedRecognition {
        let source = payload.transaction
        let page = payload.page

        switch page?.transactionStatus?.lowercased() {
        case "pending", "failed", "cancelled":
            throw RecognitionError.transactionNotCompleted
        default:
            break
        }
        if page?.multipleTransactions == true || page?.type?.lowercased() == "transaction_list" {
            throw RecognitionError.multipleTransactions
        }

        guard let amount = source.amountMinor, amount > 0 else { throw RecognitionError.missingAmount }
        guard let kind = TransactionKind(rawValue: source.type) else { throw RecognitionError.invalidResponse }

        let currency = (source.currency ?? "CNY").uppercased()
        guard ["CNY", "USD", "EUR", "JPY", "HKD"].contains(currency) else {
            throw RecognitionError.unsupportedCurrency
        }
        let exponent = source.currencyExponent ?? (currency == "JPY" ? 0 : 2)
        guard (0...4).contains(exponent) else { throw RecognitionError.invalidResponse }

        var warnings = payload.warnings ?? []
        var requiresReview = false

        if page != nil {
            if page?.transactionStatus?.lowercased() != "completed" {
                warnings.append("交易完成状态不明确")
                requiresReview = true
            }
            if let amountRole = page?.amountRole?.lowercased() {
                if !amountRoleMatchesTransaction(amountRole, kind: kind) {
                    warnings.append("金额含义与交易类型不一致")
                    requiresReview = true
                }
            } else {
                warnings.append("金额含义与交易类型不一致")
                requiresReview = true
            }
        }

        let rawMerchant = source.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let merchant = sanitize(rawMerchant, fallback: "未识别商户", maxLength: 80)
        if rawMerchant.isEmpty {
            warnings.append("未识别到商户，已使用默认名称")
            requiresReview = true
        }

        var categoryID = source.categoryID ?? defaultCategory(for: kind)
        let categoryKind = categoryKinds[categoryID]
        let kindMatches = categoryKind == nil
            || categoryKind == kind
            || (kind == .refund && categoryKind == .income)
        if source.categoryID == nil || !allowedCategoryIDs.contains(categoryID) || !kindMatches {
            categoryID = defaultCategory(for: kind)
            warnings.append("模型返回的分类无效，已使用默认分类")
            requiresReview = true
        }

        let parsedDate = parseDate(source.occurredAt)
        let occurredAt = parsedDate ?? now
        if let rawDate = source.occurredAt,
           !rawDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parsedDate == nil {
            warnings.append("交易时间格式无效，已使用当前时间")
            requiresReview = true
        }
        if occurredAt > now.addingTimeInterval(300) {
            warnings.append("交易时间晚于当前时间")
            requiresReview = true
        }
        if occurredAt < now.addingTimeInterval(-366 * 24 * 3600) {
            warnings.append("交易时间距今超过一年")
            requiresReview = true
        }

        let confidence = min(1, max(0, payload.confidence?.overall ?? 0.5))
        let ocrAmounts = OCRAmountExtractor.amountsMinor(in: ocrText)
        if !ocrAmounts.isEmpty && !ocrAmounts.contains(amount) {
            warnings.append("模型金额与本地 OCR 候选不一致")
            requiresReview = true
        } else {
            let preferredOCRAmounts = OCRAmountExtractor.preferredAmountsMinor(in: ocrText)
            if !preferredOCRAmounts.isEmpty && !preferredOCRAmounts.contains(amount) {
                warnings.append("模型金额与本地 OCR 候选不一致")
                requiresReview = true
            }
        }

        if confidence < autoSaveThreshold {
            warnings.append("置信度低于自动入账阈值")
            requiresReview = true
        }
        if amount >= highValueThresholdMinor {
            warnings.append("金额达到大额确认阈值")
            requiresReview = true
        }
        if kind == .transfer {
            warnings.append("转账需要确认转出与转入账户")
            requiresReview = true
        }

        return ValidatedRecognition(
            kind: kind,
            amountMinor: amount,
            currencyCode: currency,
            currencyExponent: exponent,
            merchant: merchant,
            categoryID: categoryID,
            occurredAt: occurredAt,
            paymentChannel: source.paymentChannel,
            paymentMethodHint: source.paymentMethodHint,
            orderIDHint: source.orderIDHint,
            note: source.note,
            confidence: confidence,
            needsReview: requiresReview,
            warnings: warnings
        )
    }

    private static func sanitize(_ value: String?, fallback: String, maxLength: Int) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(maxLength))
    }

    private static func defaultCategory(for kind: TransactionKind) -> String {
        switch kind {
        case .expense: "expense.other"
        case .income: "income.other"
        case .refund: "income.refund"
        case .transfer: "transfer.account"
        }
    }

    private static func amountRoleMatchesTransaction(_ role: String, kind: TransactionKind) -> Bool {
        switch (kind, role) {
        case (.expense, "paid"), (.income, "received"), (.refund, "refunded"), (.transfer, "transferred"):
            return true
        default:
            return false
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

enum OCRAmountExtractor {
    struct Candidate: Equatable {
        let amountMinor: Int64
        let score: Int
        let line: String
    }

    static func amountsMinor(in text: String) -> Set<Int64> {
        Set(rankedCandidates(in: text).map(\.amountMinor))
    }

    static func preferredAmountsMinor(in text: String) -> Set<Int64> {
        let candidates = rankedCandidates(in: text)
        guard let bestScore = candidates.map(\.score).max(), bestScore >= 5 else { return [] }
        return Set(candidates.filter { $0.score == bestScore }.map(\.amountMinor))
    }

    static func rankedCandidates(in text: String) -> [Candidate] {
        let pattern = #"(?<![0-9])((?:CNY|RMB|USD|EUR|JPY|HKD)\s*|[¥￥$€]\s*)?((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,8})(?:\.[0-9]{1,2})?)(?:\s*元)?(?![0-9])"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        var candidates: [Candidate] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)

            for match in expression.matches(in: line, range: range) {
                guard let valueRange = Range(match.range(at: 2), in: line) else { continue }
                let value = String(line[valueRange]).replacingOccurrences(of: ",", with: "")
                guard let money = Money(decimalString: value), money.minorUnits > 0 else { continue }

                let currencyVisible = match.range(at: 1).location != NSNotFound
                let valueHasDecimal = value.contains(".")
                let labelAdjustment = nearestLabelAdjustment(to: match.range, in: line)
                guard currencyVisible || valueHasDecimal || labelAdjustment != nil else { continue }

                var score = currencyVisible ? 5 : (valueHasDecimal ? 2 : 0)
                score += labelAdjustment ?? 0
                candidates.append(Candidate(amountMinor: money.minorUnits, score: score, line: line))
            }
        }
        return candidates.sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.amountMinor > rhs.amountMinor : lhs.score > rhs.score
        }
    }

    private static func nearestLabelAdjustment(to amountRange: NSRange, in line: String) -> Int? {
        let source = line as NSString
        var best: (distance: Int, score: Int)?

        for label in amountLabels {
            var searchRange = NSRange(location: 0, length: source.length)
            while searchRange.length > 0 {
                let found = source.range(of: label.text, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }
                let distance: Int
                if NSMaxRange(found) <= amountRange.location {
                    distance = amountRange.location - NSMaxRange(found)
                } else if NSMaxRange(amountRange) <= found.location {
                    distance = found.location - NSMaxRange(amountRange)
                } else {
                    distance = 0
                }

                if distance <= 8,
                   best == nil || distance < best!.distance || (distance == best!.distance && label.score < best!.score) {
                    best = (distance, label.score)
                }

                let nextLocation = NSMaxRange(found)
                guard nextLocation < source.length else { break }
                searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
            }
        }
        return best?.score
    }

    private static let amountLabels: [(text: String, score: Int)] = [
        ("实际支付", 12), ("实付金额", 12), ("本次支付", 12), ("付款金额", 12),
        ("退款金额", 12), ("实际退款", 12), ("到账金额", 12), ("收款金额", 12),
        ("转账金额", 12), ("消费金额", 12), ("实收金额", 12), ("实付", 12),
        ("支付金额", 7), ("交易金额", 7), ("订单金额", 7), ("合计", 7),
        ("总计", 7), ("应付", 7), ("金额", 7),
        ("原价", -12), ("优惠金额", -12), ("优惠", -12), ("立减", -12),
        ("折扣", -12), ("红包", -12), ("积分", -12), ("账户余额", -12),
        ("可用余额", -12), ("余额", -12), ("剩余", -12), ("可用", -12),
        ("手续费", -12), ("服务费", -12), ("累计", -12), ("额度", -12),
        ("最低还款", -12), ("应还", -12)
    ]
}
