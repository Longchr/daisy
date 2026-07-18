import SwiftUI
import SwiftData

struct TransactionDrillDown: Hashable {
    let dateFilter: AppState.TransactionDateFilter
    var categoryID: String?

    init(dateFilter: AppState.TransactionDateFilter, categoryID: String? = nil) {
        self.dateFilter = dateFilter
        self.categoryID = categoryID
    }
}

struct TransactionDrillDownView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    let drillDown: TransactionDrillDown
    @State private var searchText = ""

    private var categoryMap: [String: LedgerCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var filtered: [LedgerTransaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.filter { transaction in
            let matchesDate = drillDown.dateFilter.contains(transaction.occurredAt)
            let matchesCategory = drillDown.categoryID == nil || transaction.categoryID == drillDown.categoryID
            let matchesQuery = query.isEmpty
                || transaction.merchant.localizedCaseInsensitiveContains(query)
                || (categoryMap[transaction.categoryID]?.name.localizedCaseInsensitiveContains(query) ?? false)
                || transaction.note.localizedCaseInsensitiveContains(query)
            return matchesDate && matchesCategory && matchesQuery
        }
    }

    private var sections: [(date: Date, items: [LedgerTransaction])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.occurredAt) }
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var title: String {
        if let categoryID = drillDown.categoryID,
           let category = categoryMap[categoryID] {
            return category.name
        }
        return drillDown.dateFilter.title
    }

    var body: some View {
        Group {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label("没有符合条件的账单", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text(searchText.isEmpty ? "这个范围内还没有账单。" : "试试其他关键词。")
                }
            } else {
                List {
                    ForEach(sections, id: \.date) { section in
                        Section {
                            ForEach(section.items) { transaction in
                                NavigationLink {
                                    TransactionDetailView(transaction: transaction)
                                } label: {
                                    TransactionRow(
                                        transaction: transaction,
                                        category: categoryMap[transaction.categoryID],
                                        hideAmount: settings.hideAmounts
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        TransactionDeletion.delete(
                                            transaction,
                                            in: modelContext,
                                            appState: appState
                                        )
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(section.date.formatted(.dateTime.month().day().weekday(.wide)))
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索商户、分类或备注")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.isPresentingAddTransaction = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记一笔")
            }
        }
    }
}
