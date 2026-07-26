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

struct SavedTransaction: Sendable {
    let id: UUID
    let merchant: String
    let amountMinor: Int64
    let currencyCode: String
    let currencyExponent: Int
    let accountID: UUID?

    init(_ transaction: LedgerTransaction) {
        id = transaction.id
        merchant = transaction.merchant
        amountMinor = transaction.amountMinor
        currencyCode = transaction.currencyCode
        currencyExponent = transaction.currencyExponent
        accountID = transaction.accountID
    }

    var money: Money {
        Money(
            minorUnits: amountMinor,
            currencyCode: currencyCode,
            exponent: currencyExponent
        )
    }
}

struct LedgerTransactionSnapshot: Sendable {
    let id: UUID
    let kind: TransactionKind
    let amountMinor: Int64
    let currencyCode: String
    let currencyExponent: Int
    let merchant: String
    let categoryID: String
    let accountID: UUID?
    let destinationAccountID: UUID?
    let occurredAt: Date
    let note: String
    let source: TransactionSource
    let confidence: Double?
    let idempotencyKey: String?
    let createdAt: Date
    let updatedAt: Date

    init(_ transaction: LedgerTransaction) {
        id = transaction.id
        kind = transaction.kind
        amountMinor = transaction.amountMinor
        currencyCode = transaction.currencyCode
        currencyExponent = transaction.currencyExponent
        merchant = transaction.merchant
        categoryID = transaction.categoryID
        accountID = transaction.accountID
        destinationAccountID = transaction.destinationAccountID
        occurredAt = transaction.occurredAt
        note = transaction.note
        source = transaction.source
        confidence = transaction.confidence
        idempotencyKey = transaction.idempotencyKey
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    func makeTransaction() -> LedgerTransaction {
        LedgerTransaction(
            id: id,
            kind: kind,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            currencyExponent: currencyExponent,
            merchant: merchant,
            categoryID: categoryID,
            accountID: accountID,
            destinationAccountID: destinationAccountID,
            occurredAt: occurredAt,
            note: note,
            source: source,
            confidence: confidence,
            idempotencyKey: idempotencyKey,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
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
    var wealthBucketRaw: String = ""
    var includeInNetWorth: Bool = true
    var investmentCashMinor: Int64 = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        symbol: String,
        currencyCode: String = "CNY",
        openingBalanceMinor: Int64 = 0,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        wealthBucket: WealthBucket? = nil,
        includeInNetWorth: Bool = true,
        investmentCashMinor: Int64 = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.symbol = symbol
        self.currencyCode = currencyCode
        self.openingBalanceMinor = openingBalanceMinor
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.wealthBucketRaw = (wealthBucket ?? type.defaultWealthBucket).rawValue
        self.includeInNetWorth = includeInNetWorth
        self.investmentCashMinor = max(0, investmentCashMinor)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: AccountType { AccountType(rawValue: typeRaw) ?? .other }

    var wealthBucket: WealthBucket {
        get { WealthBucket(rawValue: wealthBucketRaw) ?? type.defaultWealthBucket }
        set { wealthBucketRaw = newValue.rawValue }
    }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash
    case bank
    case savings
    case termDeposit
    case creditCard
    case paymentChannel
    case investment
    case loan
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "现金"
        case .bank: "银行卡"
        case .savings: "储蓄账户"
        case .termDeposit: "定期存款"
        case .creditCard: "信用卡"
        case .paymentChannel: "支付账户"
        case .investment: "投资账户"
        case .loan: "贷款"
        case .other: "其他"
        }
    }

    var defaultWealthBucket: WealthBucket {
        switch self {
        case .cash: .cash
        case .bank, .savings, .termDeposit: .deposit
        case .paymentChannel: .payment
        case .investment: .investment
        case .creditCard, .loan: .liability
        case .other: .other
        }
    }
}

enum WealthBucket: String, Codable, CaseIterable, Identifiable, Sendable {
    case cash
    case deposit
    case payment
    case investment
    case liability
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "现金"
        case .deposit: "银行存款"
        case .payment: "支付余额"
        case .investment: "投资资产"
        case .liability: "负债账户"
        case .other: "其他金融账户"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: "banknote.fill"
        case .deposit: "building.columns.fill"
        case .payment: "wallet.pass.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .liability: "creditcard.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

enum WealthItemNature: String, Codable, CaseIterable, Identifiable, Sendable {
    case asset
    case liability

    var id: String { rawValue }
    var title: String { self == .asset ? "资产" : "负债" }
}

enum AssetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case realEstate
    case vehicle
    case preciousMetal
    case receivable
    case insurance
    case collectible
    case mortgage
    case vehicleLoan
    case consumerLoan
    case otherAsset
    case otherLiability

    var id: String { rawValue }

    var nature: WealthItemNature {
        switch self {
        case .mortgage, .vehicleLoan, .consumerLoan, .otherLiability: .liability
        default: .asset
        }
    }

    var title: String {
        switch self {
        case .realEstate: "房产"
        case .vehicle: "车辆"
        case .preciousMetal: "贵金属"
        case .receivable: "应收款"
        case .insurance: "保险现金价值"
        case .collectible: "收藏品"
        case .mortgage: "房贷"
        case .vehicleLoan: "车贷"
        case .consumerLoan: "消费贷"
        case .otherAsset: "其他资产"
        case .otherLiability: "其他负债"
        }
    }

    var systemImage: String {
        switch self {
        case .realEstate, .mortgage: "house.fill"
        case .vehicle, .vehicleLoan: "car.fill"
        case .preciousMetal: "seal.fill"
        case .receivable: "person.crop.circle.badge.clock"
        case .insurance: "shield.fill"
        case .collectible: "archivebox.fill"
        case .consumerLoan: "banknote.fill"
        case .otherAsset, .otherLiability: "ellipsis.circle.fill"
        }
    }
}

@Model
final class AssetHolding {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var natureRaw: String
    var currentValueMinor: Int64
    var currencyCode: String
    var costMinor: Int64?
    var institution: String
    var note: String
    var valuationDate: Date
    var includeInNetWorth: Bool
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: AssetKind,
        nature: WealthItemNature? = nil,
        currentValueMinor: Int64,
        currencyCode: String = "CNY",
        costMinor: Int64? = nil,
        institution: String = "",
        note: String = "",
        valuationDate: Date = Date(),
        includeInNetWorth: Bool = true,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.natureRaw = (nature ?? kind.nature).rawValue
        self.currentValueMinor = currentValueMinor
        self.currencyCode = currencyCode
        self.costMinor = costMinor
        self.institution = institution
        self.note = note
        self.valuationDate = valuationDate
        self.includeInNetWorth = includeInNetWorth
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: AssetKind {
        get {
            if let kind = AssetKind(rawValue: kindRaw) { return kind }
            return WealthItemNature(rawValue: natureRaw) == .liability
                ? .otherLiability
                : .otherAsset
        }
        set {
            kindRaw = newValue.rawValue
            natureRaw = newValue.nature.rawValue
        }
    }

    var nature: WealthItemNature {
        WealthItemNature(rawValue: natureRaw)
            ?? AssetKind(rawValue: kindRaw)?.nature
            ?? .asset
    }
}

@Model
final class AssetValuation {
    @Attribute(.unique) var id: UUID
    var assetID: UUID
    var valueMinor: Int64
    var recordedAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        assetID: UUID,
        valueMinor: Int64,
        recordedAt: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.assetID = assetID
        self.valueMinor = valueMinor
        self.recordedAt = recordedAt
        self.note = note
    }
}

@Model
final class AccountBalanceAdjustment {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var deltaMinor: Int64
    var occurredAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        accountID: UUID,
        deltaMinor: Int64,
        occurredAt: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.accountID = accountID
        self.deltaMinor = deltaMinor
        self.occurredAt = occurredAt
        self.note = note
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
    var reserveFromCash: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        monthStart: Date,
        categoryID: String? = nil,
        amountMinor: Int64,
        reserveFromCash: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.monthStart = Calendar.current.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
        self.categoryID = categoryID
        self.amountMinor = amountMinor
        self.reserveFromCash = reserveFromCash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum FinancialPlanKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case living
    case investment
    case emergency
    case travel
    case education
    case majorPurchase
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .living: "生活安排"
        case .investment: "投资计划"
        case .emergency: "应急储备"
        case .travel: "旅行"
        case .education: "教育"
        case .majorPurchase: "大额支出"
        case .other: "其他目标"
        }
    }

    var systemImage: String {
        switch self {
        case .living: "house.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .emergency: "cross.case.fill"
        case .travel: "airplane"
        case .education: "graduationcap.fill"
        case .majorPurchase: "cart.fill"
        case .other: "target"
        }
    }
}

enum FinancialPlanStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case paused
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "进行中"
        case .paused: "已暂停"
        case .completed: "已完成"
        case .archived: "已归档"
        }
    }
}

@Model
final class FinancialPlan {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var targetAmountMinor: Int64
    var reservedCashMinor: Int64
    var heldAssetMinor: Int64
    var currencyCode: String
    var cashSourceAccountID: UUID?
    var linkedInvestmentAccountID: UUID?
    var linkedAssetID: UUID?
    var targetDate: Date?
    var statusRaw: String
    var priority: Int
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: FinancialPlanKind,
        targetAmountMinor: Int64,
        reservedCashMinor: Int64 = 0,
        heldAssetMinor: Int64 = 0,
        currencyCode: String = "CNY",
        cashSourceAccountID: UUID? = nil,
        linkedInvestmentAccountID: UUID? = nil,
        linkedAssetID: UUID? = nil,
        targetDate: Date? = nil,
        status: FinancialPlanStatus = .active,
        priority: Int = 1,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.targetAmountMinor = max(0, targetAmountMinor)
        self.reservedCashMinor = max(0, reservedCashMinor)
        self.heldAssetMinor = max(0, heldAssetMinor)
        self.currencyCode = currencyCode
        self.cashSourceAccountID = cashSourceAccountID
        self.linkedInvestmentAccountID = linkedInvestmentAccountID
        self.linkedAssetID = linkedAssetID
        self.targetDate = targetDate
        self.statusRaw = status.rawValue
        self.priority = min(3, max(0, priority))
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: FinancialPlanKind {
        get { FinancialPlanKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var status: FinancialPlanStatus {
        get { FinancialPlanStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var fundedMinor: Int64 {
        let (sum, overflow) = max(0, reservedCashMinor).addingReportingOverflow(max(0, heldAssetMinor))
        return min(targetAmountMinor, overflow ? Int64.max : sum)
    }

    var progress: Double {
        guard targetAmountMinor > 0 else { return 0 }
        return min(1, Double(fundedMinor) / Double(targetAmountMinor))
    }
}

@Model
final class RecurringReminder {
    @Attribute(.unique) var id: UUID
    var merchant: String
    var amountMinor: Int64
    var categoryID: String
    var accountID: UUID?
    var dayOfMonth: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        merchant: String,
        amountMinor: Int64,
        categoryID: String,
        accountID: UUID? = nil,
        dayOfMonth: Int,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.merchant = merchant
        self.amountMinor = amountMinor
        self.categoryID = categoryID
        self.accountID = accountID
        self.dayOfMonth = min(28, max(1, dayOfMonth))
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
