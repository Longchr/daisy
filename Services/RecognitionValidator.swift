import Foundation

enum RecognitionValidator {
    static func validate(
        _ payload: RecognitionPayload,
        ocrText: String,
        allowedCategoryIDs: Set<String>,
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
        let merchant = sanitize(source.merchant, fallback: "未识别商户", maxLength: 80)

        var warnings = payload.warnings ?? []
        var categoryID = source.categoryID ?? defaultCategory(for: kind)
        if !allowedCategoryIDs.contains(categoryID) {
            categoryID = defaultCategory(for: kind)
            warnings.append("模型返回了未知分类，已使用默认分类")
        }

        let occurredAt = parseDate(source.occurredAt) ?? now
        if occurredAt > now.addingTimeInterval(300) {
            warnings.append("交易时间晚于当前时间")
        }
        if occurredAt < now.addingTimeInterval(-366 * 24 * 3600) {
            warnings.append("交易时间距今超过一年")
        }

        let confidence = min(1, max(0, payload.confidence?.overall ?? 0.5))
        let ocrAmounts = OCRAmountExtractor.amountsMinor(in: ocrText)
        if !ocrAmounts.isEmpty && !ocrAmounts.contains(amount) {
            warnings.append("模型金额与本地 OCR 候选不一致")
        }

        let needsReview = confidence < autoSaveThreshold
            || amount >= highValueThresholdMinor
            || !warnings.isEmpty
            || kind == .transfer

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
            needsReview: needsReview,
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
