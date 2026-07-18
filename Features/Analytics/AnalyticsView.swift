import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    private var monthly: [LedgerTransaction] {
        transactions.filter { Calendar.current.isDate($0.occurredAt, equalTo: appState.selectedMonth, toGranularity: .month) }
    }

    private var categoryMap: [String: LedgerCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var categoryTotals: [CategoryTotal] {
        let expenses = monthly.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.categoryID)
        return grouped.map { id, values in
            let category = categoryMap[id]
            return CategoryTotal(
                id: id,
                name: category?.name ?? "其他",
                symbol: category?.symbol ?? "ellipsis.circle.fill",
                tint: Color(hex: category?.tintHex ?? "8A8A8E"),
                amountMinor: values.reduce(0) { $0 + $1.amountMinor }
            )
        }.sorted { $0.amountMinor > $1.amountMinor }
    }

    private var expenseMinor: Int64 { categoryTotals.reduce(0) { $0 + $1.amountMinor } }
    private var incomeMinor: Int64 {
        monthly.filter { $0.kind == .income || $0.kind == .refund }.reduce(0) { $0 + $1.amountMinor }
    }

    private var monthComparison: SpendingComparison {
        let calendar = Calendar.current
        guard let current = calendar.dateInterval(of: .month, for: appState.selectedMonth),
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: current.start),
              let previous = calendar.dateInterval(of: .month, for: previousMonth) else {
            return SpendingComparison(title: "本月", currentMinor: expenseMinor, previousMinor: 0)
        }
        return SpendingComparison(
            title: "本月",
            currentMinor: expenseTotal(in: current),
            previousMinor: expenseTotal(in: previous)
        )
    }

    private var weekComparison: SpendingComparison {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: appState.selectedMonth) else {
            return SpendingComparison(title: "近 7 天", currentMinor: 0, previousMinor: 0)
        }
        let anchor = month.contains(Date()) ? Date() : month.end.addingTimeInterval(-1)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchor)) ?? month.end
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? month.start
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start) ?? month.start
        return SpendingComparison(
            title: "近 7 天",
            currentMinor: expenseTotal(in: DateInterval(start: start, end: end)),
            previousMinor: expenseTotal(in: DateInterval(start: previousStart, end: start))
        )
    }

    private var notableExpense: LedgerTransaction? {
        let expenses = monthly.filter { $0.kind == .expense }
        guard let largest = expenses.max(by: { $0.amountMinor < $1.amountMinor }) else { return nil }
        let average = expenses.reduce(0) { $0 + $1.amountMinor } / Int64(max(1, expenses.count))
        let threshold = max(settings.highValueThresholdMinor, expenses.count > 1 ? average * 2 : 0)
        return largest.amountMinor >= threshold ? largest : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack {
                        MonthPicker(month: $appState.selectedMonth)
                        Spacer()
                    }

                    insightSummary
                    spendingComparison
                    if let notableExpense {
                        notableExpenseCard(notableExpense)
                    }
                    categoryChart
                    categoryRanking
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(DaisyTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("分析")
        }
    }

    private var insightSummary: some View {
        HStack(spacing: 12) {
            MiniMetricCard(
                title: "本月支出",
                value: settings.hideAmounts ? "••••" : Money(minorUnits: expenseMinor).formatted(),
                symbol: "arrow.up.right",
                tint: DaisyTheme.expense
            )
            MiniMetricCard(
                title: "储蓄率",
                value: settings.hideAmounts ? "••%" : savingsRate.formatted(.percent.precision(.fractionLength(0))),
                symbol: "leaf.fill",
                tint: DaisyTheme.income
            )
        }
    }

    private var savingsRate: Double {
        guard incomeMinor > 0 else { return 0 }
        return max(-1, min(1, Double(incomeMinor - expenseMinor) / Double(incomeMinor)))
    }

    private func expenseTotal(in interval: DateInterval) -> Int64 {
        transactions.filter {
            $0.kind == .expense && interval.contains($0.occurredAt)
        }.reduce(0) { $0 + $1.amountMinor }
    }

    private var spendingComparison: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("支出变化")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.left.and.right")
                        .foregroundStyle(DaisyTheme.accent)
                }
                ComparisonRow(comparison: weekComparison, hideAmounts: settings.hideAmounts)
                Divider()
                ComparisonRow(comparison: monthComparison, hideAmounts: settings.hideAmounts)
            }
        }
    }

    private func notableExpenseCard(_ transaction: LedgerTransaction) -> some View {
        NavigationLink {
            TransactionDetailView(transaction: transaction)
        } label: {
            DaisyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("一笔较高支出", systemImage: "exclamationmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(DaisyTheme.warning)
                    TransactionRow(
                        transaction: transaction,
                        category: categoryMap[transaction.categoryID],
                        hideAmount: settings.hideAmounts,
                        showsDisclosureIndicator: true
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("查看这笔账单")
    }

    private var categoryChart: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("钱花在了哪里")
                        .font(.headline)
                    Text("本月分类占比")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if categoryTotals.isEmpty {
                    ContentUnavailableView("暂无可分析数据", systemImage: "chart.pie", description: Text("支出账单会自动汇总到这里。"))
                        .frame(height: 220)
                } else {
                    ZStack {
                        Chart(categoryTotals.prefix(7)) { item in
                            SectorMark(
                                angle: .value("金额", item.amountMinor),
                                innerRadius: .ratio(0.66),
                                angularInset: 2.2
                            )
                            .cornerRadius(5)
                            .foregroundStyle(item.tint)
                        }
                        .frame(height: 230)

                        VStack(spacing: 3) {
                            Text("总支出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(settings.hideAmounts ? "••••" : Money(minorUnits: expenseMinor).formatted())
                                .font(.headline.monospacedDigit())
                        }
                    }
                    .accessibilityLabel("本月分类支出占比")
                }
            }
        }
    }

    private var categoryRanking: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("分类排行")
                    .font(.headline)

                if categoryTotals.isEmpty {
                    Text("暂无排行")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ForEach(Array(categoryTotals.prefix(6).enumerated()), id: \.element.id) { index, item in
                        Button {
                            appState.showTransactions(.month(appState.selectedMonth), categoryID: item.id)
                        } label: {
                            HStack(spacing: 12) {
                                CategoryIcon(symbol: item.symbol, tint: item.tint, size: 40)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.name)
                                            .font(.subheadline.weight(.medium))
                                        Spacer()
                                        Text(settings.hideAmounts ? "••••" : Money(minorUnits: item.amountMinor).formatted())
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                    }
                                    ProgressView(value: expenseMinor == 0 ? 0 : Double(item.amountMinor) / Double(expenseMinor))
                                        .tint(item.tint)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("categoryRanking.\(item.id)")
                        .accessibilityHint("查看该分类账单")
                        if index < min(6, categoryTotals.count) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }
}

private struct SpendingComparison {
    let title: String
    let currentMinor: Int64
    let previousMinor: Int64
}

private struct ComparisonRow: View {
    let comparison: SpendingComparison
    let hideAmounts: Bool

    private var change: Double? {
        guard comparison.previousMinor > 0 else { return nil }
        return Double(comparison.currentMinor - comparison.previousMinor) / Double(comparison.previousMinor)
    }

    private var changeText: String {
        guard let change else {
            return comparison.currentMinor == 0 ? "无支出" : "上一周期无支出"
        }
        if abs(change) < 0.005 { return "基本持平" }
        return "较上一周期\(change > 0 ? "增加" : "减少") \(abs(change).formatted(.percent.precision(.fractionLength(0))))"
    }

    private var changeColor: Color {
        guard let change else { return .secondary }
        return change > 0 ? DaisyTheme.expense : DaisyTheme.income
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(comparison.title)
                    .font(.subheadline.weight(.medium))
                Text(changeText)
                    .font(.caption)
                    .foregroundStyle(changeColor)
            }
            Spacer()
            Text(hideAmounts ? "••••" : Money(minorUnits: comparison.currentMinor).formatted())
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .accessibilityLabel(
                    hideAmounts
                        ? "金额已隐藏"
                        : Money(minorUnits: comparison.currentMinor).formatted()
                )
        }
    }
}

private struct CategoryTotal: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let tint: Color
    let amountMinor: Int64
}

private struct MiniMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
        .environmentObject(AppSettings.shared)
        .modelContainer(AppDatabase.preview.container)
}
