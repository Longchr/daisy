import Foundation
import SwiftData

@MainActor
final class AppDatabase {
    static let shared = AppDatabase()
    static let preview = AppDatabase(inMemory: true, seedPreviewData: true)
    static let uiTesting = AppDatabase(inMemory: true)

    let container: ModelContainer

    init(inMemory: Bool = false, seedPreviewData: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(
                for: LedgerTransaction.self,
                Account.self,
                LedgerCategory.self,
                RecognitionDraft.self,
                MonthlyBudget.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create Daisy data store: \(error.localizedDescription)")
        }

        if seedPreviewData {
            seedDefaults(in: container.mainContext)
            seedPreviewTransactions(in: container.mainContext)
        }
    }

    func seedIfNeeded() {
        seedDefaults(in: container.mainContext)
    }

    func recognitionCategoryDescriptors() -> [(id: String, name: String, kind: TransactionKind)] {
        let context = container.mainContext
        seedDefaults(in: context)
        let descriptor = FetchDescriptor<LedgerCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = (try? context.fetch(descriptor)) ?? []
        return categories.map { (id: $0.id, name: $0.name, kind: $0.kind) }
    }

    func saveRecognition(
        _ recognition: ValidatedRecognition,
        idempotencyKey: String? = nil
    ) throws -> SavedTransaction {
        let context = container.mainContext
        seedDefaults(in: context)
        if let duplicate = findDuplicate(
            of: recognition,
            idempotencyKey: idempotencyKey,
            in: context
        ) {
            return SavedTransaction(duplicate)
        }

        let transaction = LedgerTransaction(
            kind: recognition.kind,
            amountMinor: recognition.amountMinor,
            currencyCode: recognition.currencyCode,
            currencyExponent: recognition.currencyExponent,
            merchant: recognition.merchant,
            categoryID: recognition.categoryID,
            accountID: resolveAccountID(for: recognition, in: context),
            occurredAt: recognition.occurredAt,
            note: recognition.note ?? "",
            source: .aiScreenshot,
            confidence: recognition.confidence,
            idempotencyKey: idempotencyKey
        )
        context.insert(transaction)
        try context.save()
        return SavedTransaction(transaction)
    }

    func createDraft(
        recognition: ValidatedRecognition?,
        rawData: Data?,
        idempotencyKey: String,
        errorCode: String? = nil
    ) throws -> UUID {
        let context = container.mainContext
        let drafts = (try? context.fetch(FetchDescriptor<RecognitionDraft>())) ?? []
        if let existing = drafts.first(where: { $0.idempotencyKey == idempotencyKey }) {
            return existing.id
        }

        let draft = RecognitionDraft(
            status: recognition == nil ? .failed : .needsReview,
            transactionJSON: rawData,
            overallConfidence: recognition?.confidence,
            errorCode: errorCode,
            idempotencyKey: idempotencyKey
        )
        context.insert(draft)
        try context.save()
        return draft.id
    }

    private func findDuplicate(
        of recognition: ValidatedRecognition,
        idempotencyKey: String?,
        in context: ModelContext
    ) -> LedgerTransaction? {
        let descriptor = FetchDescriptor<LedgerTransaction>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        guard let fetched = try? context.fetch(descriptor) else { return nil }
        if let idempotencyKey,
           let exact = fetched.first(where: { $0.idempotencyKey == idempotencyKey }) {
            return exact
        }

        let recent = fetched.prefix(50)
        let normalizedMerchant = MerchantNormalizer.normalize(recognition.merchant)

        return recent.first { item in
            guard item.kind == recognition.kind,
                  item.amountMinor == recognition.amountMinor,
                  item.currencyCode == recognition.currencyCode else { return false }

            let timeDelta = abs(item.occurredAt.timeIntervalSince(recognition.occurredAt))
            let sameMerchant = MerchantNormalizer.normalize(item.merchant) == normalizedMerchant
            return timeDelta <= 180 && sameMerchant
        }
    }

    private func resolveAccountID(
        for recognition: ValidatedRecognition,
        in context: ModelContext
    ) -> UUID? {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        guard let accounts = try? context.fetch(descriptor), !accounts.isEmpty else {
            return nil
        }

        return AccountResolver.resolveID(
            accounts: accounts,
            paymentChannel: recognition.paymentChannel,
            paymentMethodHint: recognition.paymentMethodHint
        )
    }

    private func seedDefaults(in context: ModelContext) {
        let categoryCount = (try? context.fetchCount(FetchDescriptor<LedgerCategory>())) ?? 0
        if categoryCount == 0 {
            for category in DefaultCatalog.categories {
                context.insert(category)
            }
        }

        let accountCount = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        if accountCount == 0 {
            for account in DefaultCatalog.accounts {
                context.insert(account)
            }
        }

        try? context.save()
    }

    private func seedPreviewTransactions(in context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<LedgerTransaction>())) == 0 else { return }
        let calendar = Calendar.current
        let samples: [(TransactionKind, Int64, String, String, Int)] = [
            (.expense, 2860, "山茶咖啡", "expense.food", 0),
            (.expense, 18800, "盒马鲜生", "expense.grocery", -1),
            (.expense, 3250, "滴滴出行", "expense.transport", -2),
            (.income, 1280000, "工资", "income.salary", -3),
            (.expense, 6800, "网易云音乐", "expense.entertainment", -5)
        ]

        for sample in samples {
            let date = calendar.date(byAdding: .day, value: sample.4, to: Date()) ?? Date()
            context.insert(LedgerTransaction(
                kind: sample.0,
                amountMinor: sample.1,
                merchant: sample.2,
                categoryID: sample.3,
                occurredAt: date,
                source: sample.4 == 0 ? .aiScreenshot : .manual,
                confidence: sample.4 == 0 ? 0.97 : nil
            ))
        }
        try? context.save()
    }
}
