import Foundation
import SwiftData

@Model
final class LedgerTransaction {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var amountMinor: Int64
    var currencyCode: String
    var currencyExponent: Int
    var merchant: String
    var categoryID: String
    var accountID: UUID?
    var destinationAccountID: UUID?
    var occurredAt: Date
    var note: String
    var sourceRaw: String
    var confidence: Double?
    var idempotencyKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: TransactionKind,
        amountMinor: Int64,
        currencyCode: String = "CNY",
        currencyExponent: Int = 2,
        merchant: String,
        categoryID: String,
        accountID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        occurredAt: Date = Date(),
        note: String = "",
        source: TransactionSource = .manual,
        confidence: Double? = nil,
        idempotencyKey: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.currencyExponent = currencyExponent
        self.merchant = merchant
        self.categoryID = categoryID
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
        self.occurredAt = occurredAt
        self.note = note
        self.sourceRaw = source.rawValue
        self.confidence = confidence
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var source: TransactionSource {
        get { TransactionSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var money: Money {
        Money(minorUnits: amountMinor, currencyCode: currencyCode, exponent: currencyExponent)
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var symbol: String
    var currencyCode: String
    var openingBalanceMinor: Int64
    var sortOrder: Int
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        symbol: String,
        currencyCode: String = "CNY",
        openingBalanceMinor: Int64 = 0,
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.symbol = symbol
        self.currencyCode = currencyCode
        self.openingBalanceMinor = openingBalanceMinor
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }

    var type: AccountType { AccountType(rawValue: typeRaw) ?? .other }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash
    case bank
    case creditCard
    case paymentChannel
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "现金"
        case .bank: "银行卡"
        case .creditCard: "信用卡"
        case .paymentChannel: "支付账户"
        case .other: "其他"
        }
    }
}

@Model
final class LedgerCategory {
    @Attribute(.unique) var id: String
    var name: String
    var kindRaw: String
    var symbol: String
    var tintHex: String
    var sortOrder: Int
    var isSystem: Bool

    init(
        id: String,
        name: String,
        kind: TransactionKind,
        symbol: String,
        tintHex: String,
        sortOrder: Int,
        isSystem: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.symbol = symbol
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }

    var kind: TransactionKind { TransactionKind(rawValue: kindRaw) ?? .expense }
}

@Model
final class RecognitionDraft {
    @Attribute(.unique) var id: UUID
    var imagePath: String?
    var statusRaw: String
    var transactionJSON: Data?
    var overallConfidence: Double?
    var errorCode: String?
    var idempotencyKey: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        imagePath: String? = nil,
        status: RecognitionDraftStatus = .pending,
        transactionJSON: Data? = nil,
        overallConfidence: Double? = nil,
        errorCode: String? = nil,
        idempotencyKey: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.imagePath = imagePath
        self.statusRaw = status.rawValue
        self.transactionJSON = transactionJSON
        self.overallConfidence = overallConfidence
        self.errorCode = errorCode
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum RecognitionDraftStatus: String, Codable {
    case pending
    case recognizing
    case needsReview
    case completed
    case failed
}

@Model
final class MonthlyBudget {
    @Attribute(.unique) var id: UUID
    var monthStart: Date
    var categoryID: String?
    var amountMinor: Int64
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        monthStart: Date,
        categoryID: String? = nil,
        amountMinor: Int64,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.monthStart = Calendar.current.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
        self.categoryID = categoryID
        self.amountMinor = amountMinor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
