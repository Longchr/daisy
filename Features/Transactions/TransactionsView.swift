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
            let matchesDate = appState.transactionDateFilter?.contains(transaction.occurredAt) ?? true
            let matchesCategory = appState.transactionCategoryID == nil
                || transaction.categoryID == appState.transactionCategoryID
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = query.isEmpty
                || transaction.merchant.localizedCaseInsensitiveContains(query)
                || (categoryMap[transaction.categoryID]?.name.localizedCaseInsensitiveContains(query) ?? false)
                || transaction.note.localizedCaseInsensitiveContains(query)
            return matchesKind && matchesDate && matchesCategory && matchesQuery
        }
    }

    private var sections: [(date: Date, items: [LedgerTransaction])] {
        let grouped = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.occurredAt) }
        return grouped.map { (date: $0.key, items: $0.value) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView {
                        Label("还没有账单", systemImage: "leaf")
                    } description: {
                        Text("记下第一笔收支，Daisy 会从这里帮你整理。")
                    } actions: {
                        Button("记一笔") {
                            appState.isPresentingAddTransaction = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if sections.isEmpty {
                    ContentUnavailableView {
                        Label("没有符合条件的账单", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text(searchText.isEmpty ? "当前类型下还没有账单。" : "试试其他关键词或清除筛选条件。")
                    } actions: {
                        Button("清除筛选") {
                            searchText = ""
                            selectedKind = nil
                            appState.transactionDateFilter = nil
                            appState.transactionCategoryID = nil
                        }
                        .buttonStyle(.bordered)
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
                                            delete(transaction)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .accessibilityHint("查看、编辑或删除这笔账单")
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
            .safeAreaInset(edge: .top, spacing: 0) {
                activeFilterBar
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("账单类型", selection: $selectedKind) {
                            Text("全部").tag(Optional<TransactionKind>.none)
                            ForEach(TransactionKind.allCases) { kind in
                                Label(kind.title, systemImage: kind.systemImage)
                                    .tag(Optional(kind))
                        }
                        }
                    } label: {
                        Label(selectedKind?.title ?? "筛选", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(selectedKind == nil ? "筛选账单" : "当前筛选：\(selectedKind?.title ?? "全部")")
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

    @ViewBuilder
    private var activeFilterBar: some View {
        if appState.transactionDateFilter != nil || appState.transactionCategoryID != nil || selectedKind != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if let dateFilter = appState.transactionDateFilter {
                        filterControl(
                            title: dateFilter.title,
                            symbol: "calendar",
                            accessibilityLabel: "清除日期筛选"
                        ) {
                            appState.transactionDateFilter = nil
                        }
                    }
                    if appState.transactionDateFilter != nil
                        && (appState.transactionCategoryID != nil || selectedKind != nil) {
                        Divider()
                            .frame(height: 22)
                            .padding(.horizontal, 4)
                    }
                    if let categoryID = appState.transactionCategoryID {
                        filterControl(
                            title: categoryMap[categoryID]?.name ?? "分类",
                            symbol: categoryMap[categoryID]?.symbol ?? "tag.fill",
                            accessibilityLabel: "清除分类筛选"
                        ) {
                            appState.transactionCategoryID = nil
                        }
                    }
                    if appState.transactionCategoryID != nil && selectedKind != nil {
                        Divider()
                            .frame(height: 22)
                            .padding(.horizontal, 4)
                    }
                    if let selectedKind {
                        filterControl(
                            title: "只看\(selectedKind.title)",
                            symbol: selectedKind.systemImage,
                            accessibilityLabel: "清除类型筛选"
                        ) {
                            self.selectedKind = nil
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private func filterControl(
        title: String,
        symbol: String,
        accessibilityLabel: String,
        clear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(filterIdentifier(for: accessibilityLabel))
            Button {
                withAnimation(.snappy) { clear() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(accessibilityLabel)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(filterIdentifier(for: accessibilityLabel))
    }

    private func filterIdentifier(for accessibilityLabel: String) -> String {
        switch accessibilityLabel {
        case "清除日期筛选": "activeDateFilter"
        case "清除分类筛选": "activeCategoryFilter"
        default: "activeKindFilter"
        }
    }

    private func delete(_ transaction: LedgerTransaction) {
        withAnimation(.snappy) {
            TransactionDeletion.delete(transaction, in: modelContext, appState: appState)
        }
    }
}
