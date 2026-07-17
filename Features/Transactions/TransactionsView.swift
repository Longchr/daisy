import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    @State private var searchText = ""
    @State private var selectedKind: TransactionKind?

    private var categoryMap: [String: LedgerCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var filtered: [LedgerTransaction] {
        transactions.filter { transaction in
            let matchesKind = selectedKind == nil || transaction.kind == selectedKind
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = query.isEmpty
                || transaction.merchant.localizedCaseInsensitiveContains(query)
                || (categoryMap[transaction.categoryID]?.name.localizedCaseInsensitiveContains(query) ?? false)
                || transaction.note.localizedCaseInsensitiveContains(query)
            return matchesKind && matchesQuery
        }
    }

    private var sections: [(date: Date, items: [LedgerTransaction])] {
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.occurredAt) }
        return grouped.map { (date: $0.key, items: $0.value) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            delete(transaction)
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
            .navigationTitle("账单")
            .searchable(text: $searchText, prompt: "搜索商户、分类或备注")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("全部") { selectedKind = nil }
                        Divider()
                        ForEach(TransactionKind.allCases) { kind in
                            Button {
                                selectedKind = kind
                            } label: {
                                Label(kind.title, systemImage: kind.systemImage)
                            }
                        }
                    } label: {
                        Label(selectedKind?.title ?? "筛选", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.isPresentingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityIdentifier("transactionsAddButton")
                }
            }
        }
    }

    private func delete(_ transaction: LedgerTransaction) {
        withAnimation(.snappy) {
            modelContext.delete(transaction)
            try? modelContext.save()
        }
        appState.presentToast("账单已删除", style: .warning)
    }
}
