import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income
    case transfer
    case refund

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "支出"
        case .income: "收入"
        case .transfer: "转账"
        case .refund: "退款"
        }
    }

    var systemImage: String {
        switch self {
        case .expense: "arrow.up.right"
        case .income: "arrow.down.left"
        case .transfer: "arrow.left.arrow.right"
        case .refund: "arrow.uturn.backward"
        }
    }

    var amountPrefix: String {
        switch self {
        case .expense: "−"
        case .income, .refund: "+"
        case .transfer: ""
        }
    }
}

enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case aiScreenshot
    case photoImport
}
