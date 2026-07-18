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

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

enum OCRAmountExtractor {
    static func amountsMinor(in text: String) -> Set<Int64> {
        let pattern = #"(?:¥|￥|CNY\s*)?([0-9]{1,8}(?:\.[0-9]{1,2})?)"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(expression.matches(in: text, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let money = Money(decimalString: String(text[valueRange])) else { return nil }
            return money.minorUnits
        })
    }
}
