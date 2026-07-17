import Foundation

enum DefaultCatalog {
    static var categories: [LedgerCategory] {
        [
            LedgerCategory(id: "expense.food", name: "餐饮", kind: .expense, symbol: "fork.knife", tintHex: "D99058", sortOrder: 0),
            LedgerCategory(id: "expense.grocery", name: "商超", kind: .expense, symbol: "basket.fill", tintHex: "9F7AEA", sortOrder: 1),
            LedgerCategory(id: "expense.transport", name: "交通", kind: .expense, symbol: "car.fill", tintHex: "5B8DEF", sortOrder: 2),
            LedgerCategory(id: "expense.shopping", name: "购物", kind: .expense, symbol: "bag.fill", tintHex: "E17B9A", sortOrder: 3),
            LedgerCategory(id: "expense.housing", name: "居住", kind: .expense, symbol: "house.fill", tintHex: "7F8C8D", sortOrder: 4),
            LedgerCategory(id: "expense.utilities", name: "缴费", kind: .expense, symbol: "bolt.fill", tintHex: "E6B94A", sortOrder: 5),
            LedgerCategory(id: "expense.entertainment", name: "娱乐", kind: .expense, symbol: "gamecontroller.fill", tintHex: "7A6FF0", sortOrder: 6),
            LedgerCategory(id: "expense.health", name: "医疗", kind: .expense, symbol: "cross.case.fill", tintHex: "D65A5A", sortOrder: 7),
            LedgerCategory(id: "expense.education", name: "教育", kind: .expense, symbol: "book.closed.fill", tintHex: "4C9B8A", sortOrder: 8),
            LedgerCategory(id: "expense.travel", name: "旅行", kind: .expense, symbol: "airplane", tintHex: "4A90A4", sortOrder: 9),
            LedgerCategory(id: "expense.other", name: "其他", kind: .expense, symbol: "ellipsis.circle.fill", tintHex: "8A8A8E", sortOrder: 99),
            LedgerCategory(id: "income.salary", name: "工资", kind: .income, symbol: "banknote.fill", tintHex: "4F8B6F", sortOrder: 100),
            LedgerCategory(id: "income.refund", name: "退款", kind: .refund, symbol: "arrow.uturn.backward.circle.fill", tintHex: "5C9674", sortOrder: 101),
            LedgerCategory(id: "income.other", name: "其他收入", kind: .income, symbol: "plus.circle.fill", tintHex: "5C9674", sortOrder: 102),
            LedgerCategory(id: "transfer.account", name: "账户转账", kind: .transfer, symbol: "arrow.left.arrow.right.circle.fill", tintHex: "6C7A89", sortOrder: 200)
        ]
    }

    static var accounts: [Account] {
        [
            Account(name: "微信支付", type: .paymentChannel, symbol: "message.fill", sortOrder: 0),
            Account(name: "支付宝", type: .paymentChannel, symbol: "a.circle.fill", sortOrder: 1),
            Account(name: "银行卡", type: .bank, symbol: "creditcard.fill", sortOrder: 2),
            Account(name: "现金", type: .cash, symbol: "banknote.fill", sortOrder: 3)
        ]
    }
}
